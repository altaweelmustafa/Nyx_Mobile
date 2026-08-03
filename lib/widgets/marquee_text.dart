import 'dart:async';
import 'package:flutter/material.dart';

/// Single-line text pinned to [width]. If the text is short enough to fit,
/// it just sits there. If it's too long, it auto-scrolls right to reveal
/// the rest, pauses, then jumps back to the start and repeats -- like a
/// classic marquee/ticker.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double width;
  final Duration pause;
  final double pixelsPerSecond;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    required this.width,
    this.pause = const Duration(seconds: 1),
    this.pixelsPerSecond = 30,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restart());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.width != widget.width) {
      _timer?.cancel();
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _restart());
    }
  }

  void _restart() {
    _timer?.cancel();
    if (!mounted || !_scrollController.hasClients) return;
    final overflow = _scrollController.position.maxScrollExtent;
    if (overflow <= 0) return;
    _timer = Timer(widget.pause, _slideRight);
  }

  Future<void> _slideRight() async {
    if (!mounted || !_scrollController.hasClients) return;
    final overflow = _scrollController.position.maxScrollExtent;
    if (overflow <= 0) return;
    final duration = Duration(
      milliseconds: (overflow / widget.pixelsPerSecond * 1000).round(),
    );
    await _scrollController.animateTo(
      overflow,
      duration: duration,
      curve: Curves.linear,
    );
    if (!mounted) return;
    _timer = Timer(widget.pause, () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
      _restart();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
      ),
    );
  }
}
