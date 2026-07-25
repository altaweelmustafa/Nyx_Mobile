import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import 'thumbnail.dart';
import 'waveform_scrubber.dart';

class HomeMiniPlayer extends StatefulWidget {
  final VoidCallback onTap;

  const HomeMiniPlayer({super.key, required this.onTap});

  @override
  State<HomeMiniPlayer> createState() => _HomeMiniPlayerState();
}

class _HomeMiniPlayerState extends State<HomeMiniPlayer> {
  bool   _isPlaying = true;
  bool   _isShuffle = false;
  bool   _isRepeat  = false;
  double _progress  = 0.38;

  @override
  Widget build(BuildContext context) {
    final track = mockTracks[3]; // On My Way

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        // Full width, 12 px margin each side — matches PDF card
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Row 1: thumbnail top-left ──────────────────────────────
              Thumbnail(
                size: 44,
                borderRadius: 6,
                child: const Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.background,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Row 2: title ───────────────────────────────────────────
              Text(
                'Title: ${track.title}',
                style: const TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // ── Row 3: bluetooth ───────────────────────────────────────
              Row(
                children: const [
                  Icon(Icons.bluetooth, size: 13, color: AppColors.accent),
                  SizedBox(width: 5),
                  Text(
                    "Bluetooth's Device name",
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Row 4: transport controls ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CtrlBtn(
                    icon: Icons.shuffle,
                    size: 22,
                    color: _isShuffle ? AppColors.accent : AppColors.textPrimary,
                    onTap: () => setState(() => _isShuffle = !_isShuffle),
                  ),
                  _CtrlBtn(
                    icon: Icons.skip_previous,
                    size: 28,
                    color: AppColors.textPrimary,
                    onTap: () {},
                  ),
                  _CtrlBtn(
                    icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                    color: AppColors.textPrimary,
                    onTap: () => setState(() => _isPlaying = !_isPlaying),
                  ),
                  _CtrlBtn(
                    icon: Icons.skip_next,
                    size: 28,
                    color: AppColors.textPrimary,
                    onTap: () {},
                  ),
                  _CtrlBtn(
                    icon: Icons.repeat,
                    size: 22,
                    color: _isRepeat ? AppColors.accent : AppColors.textPrimary,
                    onTap: () => setState(() => _isRepeat = !_isRepeat),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Row 5: waveform progress bar ───────────────────────────
              WaveformScrubber(
                progress: _progress,
                height: 40,
                onChanged: (v) => setState(() => _progress = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Control button ─────────────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final double   size;
  final Color    color;
  final VoidCallback onTap;

  const _CtrlBtn({
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
