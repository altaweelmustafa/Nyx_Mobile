import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/search_history_repository.dart';
import '../repositories/track_repository.dart';
import '../services/audio_player_service.dart';
import '../widgets/artist_label.dart';
import '../widgets/playlist_deck_card.dart';
import '../widgets/track_row_tap.dart';
import '../widgets/track_thumbnail.dart';
import 'artist_screen.dart';
import 'playlist_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearching = false;
  String _query = '';

  final _trackRepo = TrackRepository();
  final _playlistRepo = PlaylistRepository();
  final _historyRepo = SearchHistoryRepository();

  List<String> _history = [];
  List<Track> _results = [];
  List<({String name, String? thumbnailPath})> _artistResults = [];
  List<Playlist> _playlistResults = [];
  final Map<String, List<String?>> _playlistThumbnails = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(() {
      final query = _controller.text;
      setState(() => _query = query);
      _search(query);
    });
  }

  Future<void> _loadHistory() async {
    final history = await _historyRepo.getAll();
    if (!mounted) return;
    setState(() => _history = history);
  }

  /// Queries the DB directly (capped at 10 each -- see TrackRepository)
  /// instead of holding the whole library in memory and filtering in Dart.
  /// Guards against a slow, now-stale response landing after a faster one
  /// for a more recent keystroke.
  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _artistResults = [];
        _playlistResults = [];
      });
      return;
    }
    final results = await _trackRepo.searchTracks(query);
    final artistResults = await _trackRepo.searchArtists(query);
    final playlistResults = await _playlistRepo.searchPlaylists(query);
    final playlistThumbnails = await Future.wait(
      playlistResults.map(
        (p) async => MapEntry(p.id, await _playlistRepo.getTrackThumbnails(p.id)),
      ),
    );
    if (!mounted || query != _query) return;
    setState(() {
      _results = results;
      _artistResults = artistResults;
      _playlistResults = playlistResults;
      _playlistThumbnails
        ..clear()
        ..addEntries(playlistThumbnails);
    });
  }

  void _recordSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _historyRepo.add(trimmed).then((_) => _loadHistory());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    _focusNode.requestFocus();
  }

  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _query = '';
    });
    _controller.clear();
    _focusNode.unfocus();
  }

  void _removeHistory(String item) {
    setState(() => _history.remove(item));
    _historyRepo.remove(item);
  }

  void _openArtist(String artist, String? thumbnailPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ArtistScreen(artist: artist, thumbnailPath: thumbnailPath),
      ),
    );
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: playlist)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: boundToDesktopWidth(
        context,
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Search bar row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onTap: _startSearch,
                        onSubmitted: _recordSearch,
                        style: const TextStyle(
                          fontFamily: AppFonts.sans,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'SEARCH',
                          labelStyle: const TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 11,
                            letterSpacing: 1.4,
                            color: AppColors.textSecondary,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          floatingLabelAlignment: FloatingLabelAlignment.start,
                          filled: true,
                          fillColor: AppColors.surfaceHigh,
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            20,
                            16,
                            10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isSearching) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _cancelSearch,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Body ────────────────────────────────────────────────────────
              Expanded(
                child: _query.isNotEmpty
                    ? _ResultsList(
                        results: _results,
                        artistResults: _artistResults,
                        playlistResults: _playlistResults,
                        playlistThumbnails: _playlistThumbnails,
                        onTap: (index) {
                          _recordSearch(_query);
                          handleTrackTap(context, _results, index);
                        },
                        onTapArtist: (artist, thumbnailPath) {
                          _recordSearch(_query);
                          _openArtist(artist, thumbnailPath);
                        },
                        onTapPlaylist: (playlist) {
                          _recordSearch(_query);
                          _openPlaylist(playlist);
                        },
                      )
                    : _HistoryList(
                        history: _history,
                        onRemove: _removeHistory,
                        onTap: (q) {
                          _controller.text = q;
                          _startSearch();
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── History list ───────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<String> history;
  final void Function(String) onRemove;
  final void Function(String) onTap;

  const _HistoryList({
    required this.history,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Text('History', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        ...history.map(
          (item) => _HistoryRow(
            text: item,
            onTap: () => onTap(item),
            onRemove: () => onRemove(item),
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _HistoryRow({
    required this.text,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results list ───────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final List<Track> results;
  final List<({String name, String? thumbnailPath})> artistResults;
  final List<Playlist> playlistResults;
  final Map<String, List<String?>> playlistThumbnails;
  final void Function(int index) onTap;
  final void Function(String artist, String? thumbnailPath) onTapArtist;
  final void Function(Playlist playlist) onTapPlaylist;

  const _ResultsList({
    required this.results,
    required this.artistResults,
    required this.playlistResults,
    required this.playlistThumbnails,
    required this.onTap,
    required this.onTapArtist,
    required this.onTapPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty && artistResults.isEmpty && playlistResults.isEmpty) {
      return const Center(
        child: Text(
          'No results',
          style: TextStyle(
            fontFamily: AppFonts.sans,
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    final currentTrackId = context.watch<AudioPlayerService>().currentTrack?.id;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (artistResults.isNotEmpty) ...[
          const Text(
            'Artists',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: artistResults.length,
              itemBuilder: (context, i) {
                final artist = artistResults[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: i < artistResults.length - 1 ? 16 : 0,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTapArtist(artist.name, artist.thumbnailPath),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        children: [
                          TrackThumbnail(
                            size: 76,
                            assetPath: artist.thumbnailPath,
                            borderRadius: 38,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            artist.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (playlistResults.isNotEmpty) ...[
          const Text(
            'Playlists',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 188,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: playlistResults.length,
              itemBuilder: (context, i) {
                final playlist = playlistResults[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: i < playlistResults.length - 1 ? 16 : 0,
                  ),
                  child: PlaylistDeckCard(
                    playlist: playlist,
                    thumbnails: playlistThumbnails[playlist.id] ?? const [],
                    onTap: () => onTapPlaylist(playlist),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (results.isNotEmpty) ...[
          if (artistResults.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Songs',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ...results.asMap().entries.map((entry) {
            final i = entry.key;
            final track = entry.value;
            final isNowPlaying = track.id == currentTrackId;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    TrackThumbnail(
                      size: 46,
                      assetPath: track.thumbnailPath,
                      borderRadius: 6,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isNowPlaying
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ArtistLabel(
                            artist: track.artist,
                            thumbnailPath: track.thumbnailPath,
                            style: const TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
