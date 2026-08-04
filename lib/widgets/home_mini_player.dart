import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service.dart';
import 'bluetooth_indicator.dart';
import 'loop_mode_button.dart';
import 'waveform_scrubber.dart';

class HomeMiniPlayer extends StatelessWidget {
  final VoidCallback onTap;

  const HomeMiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final svc   = context.watch<AudioPlayerService>();
    final track = svc.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surfaceHigh, // fallback if no art
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [

              // ── Layer 1: album art as background ────────────────────────────
              if (track.thumbnailPath case final path?)
                if (path.startsWith('http://') || path.startsWith('https://'))
                  CachedNetworkImage(
                    imageUrl: path,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppColors.surfaceHigh),
                  )
                else
                  Image.asset(
                    path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppColors.surfaceHigh),
                  ),

              // ── Layer 2: dark gradient overlay so text is readable ──────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),

              // ── Layer 3: content ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Brager icon top-left
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'B',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Title
                    Text(
                      track.title,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // Artist
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

                    const Spacer(flex: 1),

                    // Bluetooth row
                    const BluetoothIndicator(iconSize: 12, fontSize: 11, nameWidth: 220),

                    const SizedBox(height: 14),

                    // Transport controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Btn(
                          icon: Icons.shuffle,
                          size: 20,
                          color: svc.isShuffle ? AppColors.accent : Colors.white,
                          onTap: svc.toggleShuffle,
                        ),
                        _Btn(
                          icon: Icons.skip_previous,
                          size: 26,
                          color: Colors.white,
                          onTap: svc.playPrevious,
                        ),
                        _Btn(
                          icon: svc.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 30,
                          color: Colors.white,
                          onTap: svc.togglePlayPause,
                        ),
                        _Btn(
                          icon: Icons.skip_next,
                          size: 26,
                          color: Colors.white,
                          onTap: svc.playNext,
                        ),
                        LoopModeButton(loopMode: svc.loopMode, onTap: svc.toggleRepeat, size: 20, inactiveColor: Colors.white),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Waveform — white active on top of blurred art looks great
                    WaveformScrubber(
                      progress: svc.progress,
                      height: 36,
                      activeColor: Colors.white,
                      passiveColor: Colors.white.withOpacity(0.22),
                      thumbColor: Colors.white,
                      thumbRadius: 8,
                      onChanged: (v) => svc.seekToFraction(v),
                    ),
                  ],
                ),
              ),
            ],
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
