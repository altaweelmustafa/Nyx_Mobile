import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

/// Replaces the OS-native title bar (hidden via TitleBarStyle.hidden in
/// main.dart) with one drawn to match the rest of the app instead of
/// looking like a generic GTK/Win32 window -- a drag-to-move region plus
/// our own minimize/maximize/close, the way Spotify/Discord/VS Code do it.
/// Desktop platforms only; wired in once at the MaterialApp root via
/// `builder` so it stays above every screen, not just the first one.
class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NYX',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _TitleBarButton(icon: Icons.remove, onTap: () => windowManager.minimize()),
          _TitleBarButton(
            icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            iconSize: _isMaximized ? 13 : 14,
            onTap: _toggleMaximize,
          ),
          _TitleBarButton(
            icon: Icons.close,
            onTap: () => windowManager.close(),
            hoverColor: const Color(0xFFE81123),
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  final Color? hoverColor;

  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 16,
    this.hoverColor,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 36,
          alignment: Alignment.center,
          color: _hovering
              ? (widget.hoverColor ?? AppColors.surfaceHigh)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _hovering && widget.hoverColor != null
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
