import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service.dart';
import 'loop_mode_button.dart';
import 'track_thumbnail.dart';
import 'waveform_scrubber.dart';

/// Compact mini player shown on Library and Search tabs.
class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AudioPlayerService>();
    final track = svc.currentTrack;

    // Hide if nothing has been played yet
    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TrackThumbnail(size: 42, assetPath: track.thumbnailPath, borderRadius: 6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(Icons.bluetooth, size: 11, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text(
                            "Bluetooth's Device name",
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 11,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: svc.toggleShuffle,
                  child: Icon(
                    Icons.shuffle,
                    color: svc.isShuffle ? AppColors.accent : AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: svc.playPrevious,
                  child: const Icon(Icons.skip_previous, color: AppColors.textPrimary, size: 22),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: svc.togglePlayPause,
                  child: svc.isLoading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          svc.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: AppColors.textPrimary,
                          size: 26,
                        ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: svc.playNext,
                  child: const Icon(Icons.skip_next, color: AppColors.textPrimary, size: 22),
                ),
                const SizedBox(width: 8),
                LoopModeButton(loopMode: svc.loopMode, onTap: svc.toggleRepeat, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            WaveformScrubber(
              progress: svc.progress,
              height: 28,
              thumbRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
