import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import 'thumbnail.dart';

class MiniPlayer extends StatefulWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _isPlaying = true;
  double _progress = 0.35;

  @override
  Widget build(BuildContext context) {
    final track = mockTracks[3]; // On My Way

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Album art
                Thumbnail(size: 42, borderRadius: 6),
                const SizedBox(width: 12),
                // Track info
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
                        children: [
                          const Icon(
                            Icons.bluetooth,
                            size: 11,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          const Text(
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
                // Controls
                _PlayerIcon(icon: Icons.shuffle, size: 20),
                const SizedBox(width: 8),
                _PlayerIcon(icon: Icons.skip_previous, size: 22),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _isPlaying = !_isPlaying),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 8),
                _PlayerIcon(icon: Icons.skip_next, size: 22),
                const SizedBox(width: 8),
                _PlayerIcon(icon: Icons.repeat, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            // Waveform-style progress bar
            _WaveProgress(progress: _progress),
          ],
        ),
      ),
    );
  }
}

class _PlayerIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _PlayerIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: AppColors.textPrimary, size: size);
  }
}

class _WaveProgress extends StatelessWidget {
  final double progress;

  const _WaveProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 28,
        child: CustomPaint(
          painter: _WavePainter(progress: progress),
          size: Size(MediaQuery.of(context).size.width, 28),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;

  _WavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 2.0;
    final total = ((size.width) / (barWidth + gap)).floor();

    // Wave heights pattern
    final heights = List.generate(total, (i) {
      final t = i / total;
      final h1 = 0.3 + 0.5 * (0.5 + 0.5 * _sin(t * 12));
      final h2 = 0.2 + 0.3 * (0.5 + 0.5 * _sin(t * 25 + 1.5));
      return (h1 + h2).clamp(0.15, 1.0);
    });

    final passivePaint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = AppColors.accent
      ..strokeCap = StrokeCap.round;

    final cutoff = (total * progress).round();

    for (int i = 0; i < total; i++) {
      final x = i * (barWidth + gap);
      final barH = heights[i] * size.height;
      final top = (size.height - barH) / 2;

      final rect = Rect.fromLTWH(x, top, barWidth, barH);
      final paint = i < cutoff ? activePaint : passivePaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  double _sin(double x) => (x % (2 * 3.14159) < 3.14159) ? 1.0 : -1.0;

  @override
  bool shouldRepaint(_WavePainter old) => old.progress != progress;
}
