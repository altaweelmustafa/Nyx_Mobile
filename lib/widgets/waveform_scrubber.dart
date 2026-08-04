import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaveformScrubber extends StatefulWidget {
  final double progress;
  final double height;
  final Color activeColor;
  final Color passiveColor;
  final Color thumbColor;
  final double thumbRadius;
  final List<double>? bars; // real amplitude data from WaveformService
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const WaveformScrubber({
    super.key,
    required this.progress,
    this.height = 40,
    this.activeColor = AppColors.accent,
    this.passiveColor = Colors.white,
    this.thumbColor = AppColors.textPrimary,
    this.thumbRadius = 9.0,
    this.bars,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _fraction(BuildContext context, Offset globalPos) {
    final box = context.findRenderObject() as RenderBox;
    final localX = box.globalToLocal(globalPos).dx;
    return (localX / box.size.width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _WaveformPainter(
            progress: widget.progress,
            activeColor: widget.activeColor,
            passiveColor: widget.passiveColor,
            thumbColor: widget.thumbColor,
            thumbRadius: widget.thumbRadius,
            bars: widget.bars,
            time: _controller.value,
          ),
        ),
      ),
    );

    if (widget.onChanged == null && widget.onChangeEnd == null) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        final v = _fraction(context, d.globalPosition);
        widget.onChanged?.call(v);
        widget.onChangeEnd?.call(v);
      },
      onHorizontalDragUpdate: (d) {
        widget.onChanged?.call(_fraction(context, d.globalPosition));
      },
      onHorizontalDragEnd: (_) {
        widget.onChangeEnd?.call(widget.progress);
      },
      child: child,
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

// Translucent white layers drawn behind the progress bar, each with its own
// phase speed and amplitude so they drift out of sync. Always visible,
// independent of playback progress.
const _kDriftLayers = [
  (opacity: 0.10, ampScale: 1.15, speed: 0.6, phaseOffset: 0.0),
  (opacity: 0.16, ampScale: 0.95, speed: -0.45, phaseOffset: 2.1),
  (opacity: 0.26, ampScale: 0.75, speed: 0.3, phaseOffset: 4.3),
];

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color passiveColor;
  final Color thumbColor;
  final double thumbRadius;
  final List<double>? bars;
  final double time;

  const _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.passiveColor,
    required this.thumbColor,
    required this.thumbRadius,
    required this.time,
    this.bars,
  });

  // Fallback: sine-based amplitude when no real waveform data is available.
  double _sineAmplitude(double t) {
    final w1 = 0.5 + 0.5 * math.sin(t * 18.0);
    final w2 = 0.5 + 0.5 * math.sin(t * 37.0 + 1.2);
    final w3 = 0.5 + 0.5 * math.sin(t * 7.0 + 0.6);
    final h = w1 * 0.50 + w2 * 0.30 + w3 * 0.20;
    final edge = math.min(t * 8, (1 - t) * 8).clamp(0.0, 1.0);
    return (h * edge).clamp(0.05, 1.0);
  }

  double _amplitudeAt(double t) {
    if (bars != null && bars!.isNotEmpty) {
      final idx = (t * (bars!.length - 1)).round().clamp(0, bars!.length - 1);
      return bars![idx].clamp(0.05, 1.0);
    }
    return _sineAmplitude(t);
  }

  // Builds a smooth, filled shape that rises upward only from [baselineY],
  // spanning the full width. The bottom edge is flush with the baseline so
  // nothing is drawn below it.
  Path _spikePath(
    Size size, {
    required double baselineY,
    double amplitudeScale = 1.0,
    double phase = 0.0,
  }) {
    final sampleCount = math.max(2, (size.width * 0.5).round());
    final maxAmp = baselineY - 2.0;

    final top = <Offset>[];
    for (int i = 0; i <= sampleCount; i++) {
      final x = size.width * (i / sampleCount);
      final t = (x / size.width).clamp(0.0, 1.0);
      final wobble = math.sin(t * 26 + phase) * 0.06;
      final amp = (_amplitudeAt(t) + wobble).clamp(0.05, 1.0) * amplitudeScale;
      top.add(Offset(x, baselineY - amp * maxAmp));
    }

    final path = Path()..moveTo(0, baselineY);
    path.lineTo(top.first.dx, top.first.dy);
    for (int i = 1; i < top.length - 1; i++) {
      final mid = Offset(
        (top[i].dx + top[i + 1].dx) / 2,
        (top[i].dy + top[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(top[i].dx, top[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(top.last.dx, top.last.dy);
    path.lineTo(size.width, baselineY);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cutoffX = (progress * size.width).clamp(0.0, size.width);

    final trackHeight = math.max(3.0, thumbRadius * 0.45);
    final barCenterY = size.height - thumbRadius;
    final baselineY = barCenterY - trackHeight / 2;

    // Ambient waveform: always-on, low-opacity, drifting layers that sit
    // above the bar and never render underneath it.
    for (final layer in _kDriftLayers) {
      final phase = time * 2 * math.pi * layer.speed + layer.phaseOffset;
      final path = _spikePath(
        size,
        baselineY: baselineY,
        amplitudeScale: layer.ampScale,
        phase: phase,
      );
      canvas.drawPath(
        path,
        Paint()..color = passiveColor.withOpacity(layer.opacity),
      );
    }

    // Progress bar track, drawn on top of the waveform.
    final trackRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, baselineY, size.width, trackHeight),
      Radius.circular(trackHeight / 2),
    );
    canvas.drawRRect(trackRRect, Paint()..color = passiveColor);

    if (cutoffX > 0) {
      canvas.save();
      canvas.clipRRect(trackRRect);
      canvas.drawRect(
        Rect.fromLTWH(0, baselineY, cutoffX, trackHeight),
        Paint()..color = activeColor,
      );
      canvas.restore();
    }

    final thumbX = cutoffX.clamp(thumbRadius, size.width - thumbRadius);
    canvas.drawCircle(
      Offset(thumbX, barCenterY),
      thumbRadius,
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.activeColor != activeColor ||
      old.passiveColor != passiveColor ||
      old.bars != bars ||
      old.time != time;
}
