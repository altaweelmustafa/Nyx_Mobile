import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../repositories/track_repository.dart';
import '../services/audio_player_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/track_thumbnail.dart';
import 'track_view_screen.dart';

/// Liked tracks, most recently liked first -- tapping a row plays that
/// track (with the rest of the liked list as its queue); tapping the heart
/// unlikes it and drops it out of this list immediately.
class LikedTracksScreen extends StatefulWidget {
  const LikedTracksScreen({super.key});

  @override
  State<LikedTracksScreen> createState() => _LikedTracksScreenState();
}

class _LikedTracksScreenState extends State<LikedTracksScreen> {
  final _trackRepo = TrackRepository();

  List<Track> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tracks = await _trackRepo.getLiked();
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loading = false;
    });
  }

  Future<void> _unlike(int index) async {
    final track = _tracks[index];
    await _trackRepo.setLiked(track.id, false);
    if (!mounted) return;
    setState(() => _tracks.removeAt(index));
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
                ],
              ),
            ),

            // ── Title ─────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text('Liked Tracks', style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
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
                            'No liked tracks yet',
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
                              onTap: () {
                                context.read<AudioPlayerService>().playQueue(_tracks, i);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TrackViewScreen(track: track),
                                  ),
                                );
                              },
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
                                      onTap: () => _unlike(i),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: AppColors.accent,
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
