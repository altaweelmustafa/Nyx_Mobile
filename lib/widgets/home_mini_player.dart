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
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.surfaceHigh),
                  )
                else
                  Image.asset(
                    path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppColors.surfaceHigh),
                  ),

              // ── Layer 2: color-tinted gradient overlay so text is readable
              // and the wash matches the art, Spotify-style ────────────────
              Container(
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

              // ── Layer 3: content ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nyx logo top-left
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset('assets/icons/nyx_logo.png'),
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
                    const BluetoothIndicator(
                      iconSize: 12,
                      fontSize: 11,
                      nameWidth: 220,
                    ),

                    const SizedBox(height: 14),

                    // Transport controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Btn(
                          icon: Icons.shuffle,
                          size: 20,
                          color: svc.isShuffle
                              ? AppColors.accent
                              : Colors.white,
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
                        LoopModeButton(
                          loopMode: svc.loopMode,
                          onTap: svc.toggleRepeat,
                          size: 20,
                          inactiveColor: Colors.white,
                        ),
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
