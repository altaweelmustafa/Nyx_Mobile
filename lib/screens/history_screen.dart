import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../repositories/track_repository.dart';
import '../repositories/playlist_repository.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/collection_header.dart';
import '../widgets/nyx_toast.dart';
import '../widgets/song_actions.dart';
import '../widgets/track_row_tap.dart';
import '../widgets/track_thumbnail.dart';

/// Recently played tracks, most recent first -- tapping a row plays it (with
/// the rest of the history list as its queue). Removing a track here just
/// clears when it was last played; it stays in the library.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _trackRepo = TrackRepository();
  final _playlistRepo = PlaylistRepository();

  List<Track> _tracks = [];
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
    final tracks = await _trackRepo.getRecentlyPlayed();
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loading = false;
    });
  }

  Future<void> _clearOne(int index) async {
    final track = _tracks[index];
    await _trackRepo.clearHistoryEntry(track.id);
    if (!mounted) return;
    setState(() => _tracks.removeAt(index));
  }

  Future<void> _clearAll() async {
    await _trackRepo.clearAllHistory();
    if (!mounted) return;
    setState(() => _tracks = []);
    NyxToast.show(context, 'History cleared', icon: Icons.delete_outline);
  }

  void _showSongOptions(int index) {
    final track = _tracks[index];
    showSongOptionsSheet(
      context,
      track: track,
      trackRepo: _trackRepo,
      playlistRepo: _playlistRepo,
      liked: track.liked,
      onLikeChanged: (liked) {
        if (!mounted) return;
        setState(() => _tracks[index] = track.copyWith(liked: liked));
      },
      removeLabel: 'Remove from History',
      onRemove: () => _clearOne(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTrackId = context.watch<AudioPlayerService>().currentTrack?.id;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary, size: 20),
                  ),
                  const Spacer(),
                  if (_tracks.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Header ────────────────────────────────────────────────────
            CollectionHeader(
              title: 'History',
              subtitle: '${_tracks.length} TRACKS',
              thumbnailPath: _tracks.isNotEmpty ? _tracks.first.thumbnailPath : null,
              onPlayAll: _tracks.isEmpty
                  ? null
                  : () => handleTrackTap(context, _tracks, 0, isPersonalPlaylist: true),
            ),

            // ── Track list ─────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : _tracks.isEmpty
                      ? const Center(
                          child: Text(
                            'No listening history yet',
                            style: TextStyle(fontFamily: AppFonts.sans, color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _tracks.length,
                          itemBuilder: (context, i) {
                            final track = _tracks[i];
                            final isNowPlaying = track.id == currentTrackId;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => handleTrackTap(
                                context,
                                _tracks,
                                i,
                                isPersonalPlaylist: true,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    TrackThumbnail(size: 46, assetPath: track.thumbnailPath, borderRadius: 6),
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
                                              color: isNowPlaying ? AppColors.accent : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            track.artist,
                                            style: const TextStyle(
                                              fontFamily: AppFonts.sans,
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showSongOptions(i),
                                      child: const Icon(
                                        Icons.more_vert,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
