import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/artwork_color_service.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service.dart';
import 'bluetooth_indicator.dart';
import 'loop_mode_button.dart';
import 'track_thumbnail.dart';
import 'waveform_scrubber.dart';

/// Compact mini player shown on Library and Search tabs.
class MiniPlayer extends StatefulWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  String? _loadedPath;
  Color? _bgColor;

  void _maybeReloadColor(String? path) {
    if (path == _loadedPath) return;
    _loadedPath = path;
    ArtworkColorService.extract(path).then((color) {
      if (!mounted || path != _loadedPath) return;
      setState(
        () => _bgColor = color == null
            ? null
            : ArtworkColorService.tuneForBackground(color),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AudioPlayerService>();
    final track = svc.currentTrack;

    // Hide if nothing has been played yet
    if (track == null) return const SizedBox.shrink();

    _maybeReloadColor(track.thumbnailPath);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
        decoration: BoxDecoration(
          color: _bgColor ?? AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TrackThumbnail(
                  size: 34,
                  assetPath: track.thumbnailPath,
                  borderRadius: 6,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          fontFamily: AppFonts.sans,
                          fontFamilyFallback: AppFonts.fallback,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const BluetoothIndicator(
                        iconSize: 11,
                        fontSize: 11,
                        nameWidth: 100,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: svc.toggleShuffle,
                  child: Icon(
                    Icons.shuffle,
                    color: svc.isShuffle
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: svc.playPrevious,
                  child: const Icon(
                    Icons.skip_previous,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
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
                  child: const Icon(
                    Icons.skip_next,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                LoopModeButton(
                  loopMode: svc.loopMode,
                  onTap: svc.toggleRepeat,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 5),
            WaveformScrubber(
              progress: svc.progress,
              height: 20,
              thumbRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
