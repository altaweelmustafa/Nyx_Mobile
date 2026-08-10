import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A pink-accented toast that dismisses itself once its bottom line finishes
/// draining -- the line IS the countdown, not just decoration. A real
/// widget (not a one-off function) so its look can be tweaked in one place;
/// [NyxToast.show] is what call sites actually use to fire one.
class NyxToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismissed;

  const NyxToast({
    super.key,
    required this.message,
    required this.onDismissed,
    this.icon = Icons.check_circle_outline,
    this.duration = const Duration(seconds: 2),
  });

  static OverlayEntry? _active;

  /// Shows a toast anchored near the top of the screen, for [duration]
  /// (default 3s). Replaces any toast already showing rather than stacking.
  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle_outline,
    Duration duration = const Duration(seconds: 2),
  }) {
    _active?.remove();
    _active = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NyxToastOverlay(
        message: message,
        icon: icon,
        duration: duration,
        onDismissed: () {
          if (_active == entry) _active = null;
          entry.remove();
        },
      ),
    );
    _active = entry;
    overlay.insert(entry);
  }

  @override
  State<NyxToast> createState() => _NyxToastState();
}

class _NyxToastState extends State<NyxToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDismissed();
      })
      ..forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        // Blur whatever's behind the toast (album art, title text, etc.)
        // instead of relying on a low-opacity fill that lets it bleed
        // through legibly.
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            fontFamily: AppFonts.sans,
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // The countdown -- shrinks from full width to nothing over
                // [duration], then the toast dismisses itself.
                AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 1 - _timer.value,
                      child: Container(height: 3, color: Colors.white),
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

/// Positions a [NyxToast] card near the top of the screen with a fade +
/// slide-in entrance. Kept separate from NyxToast itself so the card stays
/// a plain, reusable widget not tied to overlay placement.
class _NyxToastOverlay extends StatelessWidget {
  final String message;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismissed;

  const _NyxToastOverlay({
    required this.message,
    required this.icon,
    required this.duration,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -16),
            child: child,
          ),
        ),
        child: NyxToast(
          message: message,
          icon: icon,
          duration: duration,
          onDismissed: onDismissed,
        ),
      ),
    );
  }
}
