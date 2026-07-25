import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaveformScrubber extends StatelessWidget {
  final double progress;
  final double height;
  final Color activeColor;
  final Color passiveColor;
  final Color thumbColor;
  final double barWidth;
  final double barGap;
  final double thumbRadius;
  final ValueChanged<double>? onChanged;

  const WaveformScrubber({
    super.key,
    required this.progress,
    this.height = 40,
    this.activeColor = AppColors.accent,
    this.passiveColor = const Color(0x2DFFFFFF), // white @ ~18%
    this.thumbColor = AppColors.textPrimary,
    this.barWidth = 3.0,
    this.barGap = 2.0,
    this.thumbRadius = 6.0,
    this.onChanged,
  });

  void _handleDrag(BuildContext context, Offset globalPos) {
    if (onChanged == null) return;
    final box = context.findRenderObject() as RenderBox;
    final localX = box.globalToLocal(globalPos).dx;
    final v = (localX / box.size.width).clamp(0.0, 1.0);
    onChanged!(v);
  }

  @override
  Widget build(BuildContext context) {
    final painter = _WaveformPainter(
      progress:    progress,
      activeColor: activeColor,
      passiveColor: passiveColor,
      thumbColor:  thumbColor,
      barWidth:    barWidth,
      barGap:      barGap,
      thumbRadius: thumbRadius,
    );

    if (onChanged == null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: painter),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => _handleDrag(context, d.globalPosition),
      onTapDown: (d) => _handleDrag(context, d.globalPosition),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: painter),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color  activeColor;
  final Color  passiveColor;
  final Color  thumbColor;
  final double barWidth;
  final double barGap;
  final double thumbRadius;

  const _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.passiveColor,
    required this.thumbColor,
    required this.barWidth,
    required this.barGap,
    required this.thumbRadius,
  });

  /// Deterministic waveform height for bar [i] out of [total].
  /// Uses overlapping sines to produce an organic mountain silhouette.
  double _barHeight(int i, int total) {
    final t  = i / total;
    final w1 = 0.5 + 0.5 * math.sin(t * 18.0);
    final w2 = 0.5 + 0.5 * math.sin(t * 37.0 + 1.2);
    final w3 = 0.5 + 0.5 * math.sin(t *  7.0 + 0.6);
    final h  = w1 * 0.50 + w2 * 0.30 + w3 * 0.20;
    // Taper edges so the waveform fades in/out cleanly
    final edge = math.min(t * 8, (1 - t) * 8).clamp(0.0, 1.0);
    return (h * edge).clamp(0.06, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total  = (size.width / (barWidth + barGap)).floor();
    final cutoff = (total * progress).round();

    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round;

    final passivePaint = Paint()
      ..color = passiveColor
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < total; i++) {
      final x    = i * (barWidth + barGap);
      final barH = (_barHeight(i, total) * size.height).clamp(2.0, size.height);
      final top  = (size.height - barH) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, barH),
          const Radius.circular(2),
        ),
        i < cutoff ? activePaint : passivePaint,
      );
    }

    // Scrubber thumb circle
    final thumbX = (cutoff * (barWidth + barGap))
        .clamp(thumbRadius, size.width - thumbRadius);
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      thumbRadius,
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress    != progress    ||
      old.activeColor != activeColor ||
      old.barWidth    != barWidth;
}
