import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../repositories/artist_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/track_repository.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../utils/artist_names.dart';
import '../widgets/responsive_card_row.dart';
import '../widgets/song_actions.dart';
import '../widgets/track_row_tap.dart';
import '../widgets/track_thumbnail.dart';
import 'artist_screen.dart';
import 'liked_tracks_screen.dart';
import 'playlist_screen.dart';

/// One card slot in the Home "Recommended" row -- either a track or an
/// artist profile (identified by name only, so it always resolves against
/// the live [_HomeScreenState._recommended] list rather than going stale).
sealed class _RecItem {}

class _RecTrackItem extends _RecItem {
  final String trackId;
  _RecTrackItem(this.trackId);
}

class _RecArtistItem extends _RecItem {
  final String artist;
  final String? thumbnailPath;
  _RecArtistItem(this.artist, this.thumbnailPath);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _trackRepo = TrackRepository();
  final _playlistRepo = PlaylistRepository();
  final _artistRepo = ArtistRepository();
  List<Playlist> _playlists = [];
  final Map<String, String?> _playlistThumbnails = {};
  int _likedCount = 0;
  String? _likedThumbnail;
  List<Track> _mostPlayed = [];
  List<Track> _recommended = [];
  List<_RecItem> _recommendedDisplay = [];
  bool _loading = true;
  LibraryService? _libSvc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch whenever anything in the library changes (like, play, sync,
    // playlist edits, ...) so this screen stays live without needing to
    // leave and come back to the tab.
    _libSvc?.removeListener(_load);
    _libSvc = context.read<LibraryService>();
    _libSvc!.addListener(_load);
  }

  @override
  void dispose() {
    _libSvc?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final playlistsFuture = _playlistRepo.getLiked();
    final likedFuture = _trackRepo.getLiked();
    final mostPlayedFuture = _trackRepo.getMostPlayed(10);
    final recommendedFuture = _trackRepo.getRecentlyAddedMix(12);

    final playlists = await playlistsFuture;
    final liked = await likedFuture;
    final mostPlayed = await mostPlayedFuture;
    final recommended = await recommendedFuture;
    final artistProfiles = await _artistRepo.getAll();
    final photoByArtist = {for (final a in artistProfiles) a.name: a.photoPath};
    final artists = _newArtistsFrom(recommended, photoByArtist);
    final thumbnails = await Future.wait(
      playlists.map((p) async {
        final tracks = await _playlistRepo.getTracks(p.id);
        return MapEntry(
          p.id,
          tracks.isNotEmpty ? tracks.first.thumbnailPath : null,
        );
      }),
    );
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
      _playlistThumbnails
        ..clear()
        ..addEntries(thumbnails);
      _likedCount = liked.length;
      _likedThumbnail = liked.isNotEmpty ? liked.first.thumbnailPath : null;
      _mostPlayed = mostPlayed;
      _recommended = recommended;
      _recommendedDisplay = _mixInArtists(recommended, artists);
      _loading = false;
    });
  }

  /// Distinct (split) artists among [tracks] -- since [tracks] already
  /// comes from getRecentlyAddedMix (one representative track per new
  /// artist), this just reads back the artist behind each representative.
  /// Prefers each artist's real synced cover ([photoByArtist]) over a
  /// track thumbnail stand-in. Capped so a big batch upload doesn't turn
  /// the row into all artist cards and no track cards.
  List<({String name, String? thumbnailPath})> _newArtistsFrom(
    List<Track> tracks,
    Map<String, String?> photoByArtist, {
    int cap = 4,
  }) {
    final seen = <String>{};
    final result = <({String name, String? thumbnailPath})>[];
    for (final track in tracks) {
      for (final name in splitArtists(track.artist)) {
        if (seen.add(name)) {
          result.add((
            name: name,
            thumbnailPath: photoByArtist[name] ?? track.thumbnailPath,
          ));
        }
      }
      if (result.length >= cap) break;
    }
    return result.take(cap).toList();
  }

  /// Splices artist cards into random positions among the recommended
  /// tracks -- recomputed on every load so it reshuffles each visit.
  List<_RecItem> _mixInArtists(
    List<Track> tracks,
    List<({String name, String? thumbnailPath})> artists,
  ) {
    final items = <_RecItem>[for (final t in tracks) _RecTrackItem(t.id)];
    final random = Random();
    for (final artist in artists) {
      final position = random.nextInt(items.length + 1);
      items.insert(position, _RecArtistItem(artist.name, artist.thumbnailPath));
    }
    return items;
  }

  void _openArtist(String artist, String? thumbnailPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ArtistScreen(artist: artist, thumbnailPath: thumbnailPath),
      ),
    );
  }

  Future<void> _openPlaylist(Playlist playlist) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: playlist)),
    );
  }

  Future<void> _openLikedTracks() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LikedTracksScreen()));
  }

  void _showSongOptions(
    List<Track> list,
    int index, {
    bool isRecommended = false,
  }) {
    final track = list[index];
    showSongOptionsSheet(
      context,
      track: track,
      trackRepo: _trackRepo,
      playlistRepo: _playlistRepo,
      liked: track.liked,
      onLikeChanged: (liked) {
        if (!mounted) return;
        setState(() => list[index] = track.copyWith(liked: liked));
      },
      removeLabel: 'Remove from Library',
      onRemove: () async {
        await _trackRepo.deleteTrack(track.id);
        if (!mounted) return;
        setState(() {
          list.removeAt(index);
          if (isRecommended) {
            _recommendedDisplay.removeWhere(
              (item) => item is _RecTrackItem && item.trackId == track.id,
            );
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: boundToDesktopWidth(
        context,
        SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 160),
                  children: [
                    const SizedBox(height: 44),

                    // ── Playlists ────────────────────────────────────────────────
                    _PlaylistRow(
                      playlists: _playlists,
                      playlistThumbnails: _playlistThumbnails,
                      likedCount: _likedCount,
                      likedThumbnail: _likedThumbnail,
                      onTap: _openPlaylist,
                      onTapLikedSongs: _openLikedTracks,
                    ),
                    const SizedBox(height: 44),

                    // ── Most Played ──────────────────────────────────────────────
                    if (_mostPlayed.isNotEmpty) ...[
                      const _SectionHeader(title: 'Most Played'),
                      const SizedBox(height: 16),
                      _TrackCardRow(
                        tracks: _mostPlayed,
                        onTap: (i) => handleTrackTap(context, _mostPlayed, i),
                        onOptionsTap: (i) => _showSongOptions(_mostPlayed, i),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // ── Recommended ──────────────────────────────────────────────
                    if (_recommendedDisplay.isNotEmpty) ...[
                      const _SectionHeader(title: 'Recommended'),
                      const SizedBox(height: 16),
                      _RecommendedRow(
                        items: _recommendedDisplay,
                        recommended: _recommended,
                        onTapTrack: (index) =>
                            handleTrackTap(context, _recommended, index),
                        onOptionsTap: (index) => _showSongOptions(
                          _recommended,
                          index,
                          isRecommended: true,
                        ),
                        onTapArtist: _openArtist,
                      ),
                      const SizedBox(height: 32),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

// ── Playlists: rounded cards with a bit of breathing room ───────────────────

class _PlaylistRow extends StatelessWidget {
  final List<Playlist> playlists;
  final Map<String, String?> playlistThumbnails;
  final int likedCount;
  final String? likedThumbnail;
  final void Function(Playlist playlist) onTap;
  final VoidCallback onTapLikedSongs;

  const _PlaylistRow({
    required this.playlists,
    required this.playlistThumbnails,
    required this.likedCount,
    required this.likedThumbnail,
    required this.onTap,
    required this.onTapLikedSongs,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveCardRow(
      mobileHeight: 68,
      spacing: 14,
      children: [
        _PlaylistTile(
          name: 'Liked Songs',
          subtitle: '$likedCount TRACKS',
          thumbnailPath: likedThumbnail,
          onTap: onTapLikedSongs,
        ),
        for (final p in playlists)
          _PlaylistTile(
            name: p.name,
            subtitle: '${p.trackCount} TRACKS',
            thumbnailPath: playlistThumbnails[p.id],
            onTap: () => onTap(p),
          ),
      ],
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? thumbnailPath;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.name,
    required this.subtitle,
    required this.thumbnailPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 216,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            TrackThumbnail(
              size: 48,
              assetPath: thumbnailPath,
              borderRadius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 10,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Most Played: plain track cards ───────────────────────────────────────────

class _TrackCardRow extends StatelessWidget {
  final List<Track> tracks;
  final void Function(int index) onTap;
  final void Function(int index) onOptionsTap;

  const _TrackCardRow({
    required this.tracks,
    required this.onTap,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    final currentTrackId = context.watch<AudioPlayerService>().currentTrack?.id;

    return ResponsiveCardRow(
      mobileHeight: 188,
      children: [
        for (int i = 0; i < tracks.length; i++)
          _TrackCard(
            track: tracks[i],
            isNowPlaying: tracks[i].id == currentTrackId,
            onTap: () => onTap(i),
            onOptionsTap: () => onOptionsTap(i),
          ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  final Track track;
  final bool isNowPlaying;
  final VoidCallback onTap;
  final VoidCallback onOptionsTap;

  const _TrackCard({
    required this.track,
    required this.isNowPlaying,
    required this.onTap,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                TrackThumbnail(
                  size: 130,
                  assetPath: track.thumbnailPath,
                  borderRadius: 10,
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onOptionsTap,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 13,
                color: isNowPlaying ? AppColors.accent : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recommended: track cards mixed with circular artist profile cards ──────

class _RecommendedRow extends StatelessWidget {
  final List<_RecItem> items;
  final List<Track> recommended;
  final void Function(int index) onTapTrack;
  final void Function(int index) onOptionsTap;
  final void Function(String artist, String? thumbnailPath) onTapArtist;

  const _RecommendedRow({
    required this.items,
    required this.recommended,
    required this.onTapTrack,
    required this.onOptionsTap,
    required this.onTapArtist,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final currentTrackId = context.watch<AudioPlayerService>().currentTrack?.id;

    final cards = <Widget>[];
    for (final item in items) {
      if (item is _RecArtistItem) {
        cards.add(
          _ArtistCard(
            name: item.artist,
            thumbnailPath: item.thumbnailPath,
            onTap: () => onTapArtist(item.artist, item.thumbnailPath),
          ),
        );
        continue;
      }

      final trackId = (item as _RecTrackItem).trackId;
      final index = recommended.indexWhere((t) => t.id == trackId);
      if (index == -1) continue;
      final track = recommended[index];
      cards.add(
        _TrackCard(
          track: track,
          isNowPlaying: track.id == currentTrackId,
          onTap: () => onTapTrack(index),
          onOptionsTap: () => onOptionsTap(index),
        ),
      );
    }

    return ResponsiveCardRow(mobileHeight: 188, children: cards);
  }
}

class _ArtistCard extends StatelessWidget {
  final String name;
  final String? thumbnailPath;
  final VoidCallback onTap;

  const _ArtistCard({
    required this.name,
    required this.thumbnailPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          children: [
            TrackThumbnail(
              size: 130,
              assetPath: thumbnailPath,
              borderRadius: 65, // circular
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Artist',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
