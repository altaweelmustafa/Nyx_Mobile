import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../services/audio_player_service.dart';
import '../widgets/track_thumbnail.dart';
import 'track_view_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final MockPlaylist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late List<MockTrack> _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = List.from(widget.playlist.tracks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz,
                        color: AppColors.textPrimary, size: 24),
                  ),
                ],
              ),
            ),

            // ── Playlist title ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                widget.playlist.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),

            // ── Track list ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tracks.length,
                itemBuilder: (context, i) {
                  final track = _tracks[i];
                  return GestureDetector(
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
                          // Thumbnail
                          TrackThumbnail(size: 46, assetPath: track.thumbnailPath, borderRadius: 6),
                          const SizedBox(width: 14),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.sans,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  track.song,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.mono,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
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
                          // Heart
                          GestureDetector(
                            onTap: () {
                              setState(() => track.liked = !track.liked);
                            },
                            child: Icon(
                              track.liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: track.liked
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
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
