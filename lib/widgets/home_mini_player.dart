import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/artwork_color_service.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service.dart';
import 'bluetooth_indicator.dart';
import 'loop_mode_button.dart';
import 'waveform_scrubber.dart';

class HomeMiniPlayer extends StatefulWidget {
  final VoidCallback onTap;

  const HomeMiniPlayer({super.key, required this.onTap});

  @override
  State<HomeMiniPlayer> createState() => _HomeMiniPlayerState();
}

class _HomeMiniPlayerState extends State<HomeMiniPlayer> {
  String? _loadedPath;
  Color? _tint;

  void _maybeReloadColor(String? path) {
    if (path == _loadedPath) return;
    _loadedPath = path;
    ArtworkColorService.extract(path).then((color) {
      if (!mounted || path != _loadedPath) return;
      setState(() => _tint = color);
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
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surfaceHigh,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.20,
            ),
            child: Stack(
              children: [
                if (track.thumbnailPath case final path?)
                  Positioned.fill(
                    child:
                        path.startsWith('http://') ||
                            path.startsWith('https://')
                        ? CachedNetworkImage(
                            imageUrl: path,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: AppColors.surfaceHigh),
                          )
                        : Image.asset(
                            path,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: AppColors.surfaceHigh),
                          ),
                  ),

                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (_tint == null
                                  ? Colors.black
                                  : Color.lerp(_tint, Colors.black, 0.35)!)
                              .withOpacity(0.4),
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content now fills the card's full (fixed) height and
                // spaces its two groups apart, instead of being wrapped
                // in a scroll view that let it collapse to the top and
                // leave dead space below.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top group: identity ──────────────────────
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/icons/nyx_logo.png',
                                  width: 22,
                                  height: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    track.title,
                                    style: const TextStyle(
                                      fontFamily: AppFonts.sans,
                                      fontFamilyFallback: AppFonts.fallback,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              style: TextStyle(
                                fontFamily: AppFonts.mono,
                                fontFamilyFallback: AppFonts.fallback,
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            const BluetoothIndicator(
                              iconSize: 12,
                              fontSize: 11,
                              nameWidth: 200,
                            ),
                          ],
                        ),

                        // ── Bottom group: controls ────────────────────
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _Btn(
                                  icon: Icons.shuffle,
                                  size: 18,
                                  color: svc.isShuffle
                                      ? AppColors.accent
                                      : Colors.white,
                                  onTap: svc.toggleShuffle,
                                ),
                                _Btn(
                                  icon: Icons.skip_previous,
                                  size: 23,
                                  color: Colors.white,
                                  onTap: svc.playPrevious,
                                ),
                                _Btn(
                                  icon: svc.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  size: 28,
                                  color: Colors.white,
                                  onTap: svc.togglePlayPause,
                                ),
                                _Btn(
                                  icon: Icons.skip_next,
                                  size: 23,
                                  color: Colors.white,
                                  onTap: svc.playNext,
                                ),
                                LoopModeButton(
                                  loopMode: svc.loopMode,
                                  onTap: svc.toggleRepeat,
                                  size: 18,
                                  inactiveColor: Colors.white,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            WaveformScrubber(
                              progress: svc.progress,
                              height: 20,
                              activeColor: Colors.white,
                              passiveColor: Colors.white.withOpacity(0.22),
                              thumbColor: Colors.white,
                              thumbRadius: 7,
                              onChanged: (v) => svc.seekToFraction(v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  const _Btn({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, color: color, size: size),
  );
}
