import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/artwork_color_service.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import 'bluetooth_indicator.dart';
import 'loop_mode_button.dart';
import 'track_thumbnail.dart';
import 'waveform_scrubber.dart';

/// Full-width playback bar pinned to the bottom of the window on desktop
/// (context.isDesktop) -- replaces the mobile MiniPlayer/HomeMiniPlayer
/// pair with one consistent bar. Used by both ShellScreen (the 3 main
/// tabs) and AppScaffold (every screen pushed on top of it), so playback
/// controls look and behave the same regardless of which screen is up.
class DesktopPlayerBar extends StatefulWidget {
  final VoidCallback onTap;

  const DesktopPlayerBar({super.key, required this.onTap});

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar> {
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
    if (track == null) return const SizedBox.shrink();

    _maybeReloadColor(track.thumbnailPath);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _bgColor ?? AppColors.surfaceHigh,
          border: const Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            TrackThumbnail(
              size: 56,
              assetPath: track.thumbnailPath,
              borderRadius: 8,
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 220,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: svc.toggleShuffle,
                        child: Icon(
                          Icons.shuffle,
                          size: 18,
                          color: svc.isShuffle
                              ? AppColors.accent
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: svc.playPrevious,
                        child: const Icon(
                          Icons.skip_previous,
                          size: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: svc.togglePlayPause,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: svc.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    color: AppColors.background,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  svc.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: AppColors.background,
                                  size: 20,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: svc.playNext,
                        child: const Icon(
                          Icons.skip_next,
                          size: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 20),
                      LoopModeButton(
                        loopMode: svc.loopMode,
                        onTap: svc.toggleRepeat,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  WaveformScrubber(
                    progress: svc.progress,
                    height: 18,
                    thumbRadius: 5,
                    onChanged: (v) => svc.seekToFraction(v),
                    onChangeEnd: (v) => svc.seekToFraction(v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            const BluetoothIndicator(
              iconSize: 13,
              fontSize: 11,
              nameWidth: 140,
            ),
          ],
        ),
      ),
    );
  }
}
