import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/track_repository.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../widgets/song_actions.dart';
import '../widgets/track_thumbnail.dart';
import 'track_view_screen.dart';

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
    final mostPlayedFuture = _trackRepo.getMostPlayed(10);
    final recommendedFuture = _trackRepo.getRecommendedMix(12);
    final artistsFuture = _trackRepo.getRandomArtists(2);

    final mostPlayed = await mostPlayedFuture;
    final recommended = await recommendedFuture;
    final artists = await artistsFuture;
    if (!mounted) return;
    setState(() {
      _mostPlayed = mostPlayed;
      _recommended = recommended;
      _recommendedDisplay = _mixInArtists(recommended, artists);
      _loading = false;
    });
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

  void _play(BuildContext context, List<Track> queue, int index) {
    context.read<AudioPlayerService>().playQueue(queue, index);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackViewScreen(track: queue[index])),
    );
  }

  Future<void> _playArtist(String artist) async {
    final tracks = await _trackRepo.getByArtist(artist);
    if (!mounted || tracks.isEmpty) return;
    _play(context, tracks, 0);
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
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 160),
                children: [
                  const SizedBox(height: 24),

                  // ── Most Played ──────────────────────────────────────────────
                  if (_mostPlayed.isNotEmpty) ...[
                    const _SectionHeader(title: 'Most Played'),
                    const SizedBox(height: 16),
                    _TrackCardRow(
                      tracks: _mostPlayed,
                      onTap: (i) => _play(context, _mostPlayed, i),
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
                          _play(context, _recommended, index),
                      onOptionsTap: (index) => _showSongOptions(
                        _recommended,
                        index,
                        isRecommended: true,
                      ),
                      onTapArtist: _playArtist,
                    ),
                    const SizedBox(height: 32),
                  ],

                  const SizedBox(height: 40),
                ],
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

    return SizedBox(
      height: 188,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tracks.length,
        itemBuilder: (context, i) {
          final track = tracks[i];
          final isNowPlaying = track.id == currentTrackId;
          return Padding(
            padding: EdgeInsets.only(right: i < tracks.length - 1 ? 12 : 0),
            child: _TrackCard(
              track: track,
              isNowPlaying: isNowPlaying,
              onTap: () => onTap(i),
              onOptionsTap: () => onOptionsTap(i),
            ),
          );
        },
      ),
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
  final void Function(String artist) onTapArtist;

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

    return SizedBox(
      height: 188,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final padding = EdgeInsets.only(right: i < items.length - 1 ? 12 : 0);

          if (item is _RecArtistItem) {
            return Padding(
              padding: padding,
              child: _ArtistCard(
                name: item.artist,
                thumbnailPath: item.thumbnailPath,
                onTap: () => onTapArtist(item.artist),
              ),
            );
          }

          final trackId = (item as _RecTrackItem).trackId;
          final index = recommended.indexWhere((t) => t.id == trackId);
          if (index == -1) return const SizedBox.shrink();
          final track = recommended[index];

          return Padding(
            padding: padding,
            child: _TrackCard(
              track: track,
              isNowPlaying: track.id == currentTrackId,
              onTap: () => onTapTrack(index),
              onOptionsTap: () => onOptionsTap(index),
            ),
          );
        },
      ),
    );
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
