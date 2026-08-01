import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

/// Tappable repeat/loop button that cycles through none → one → all → none.
/// Shows a distinct icon and color for each state.
class LoopModeButton extends StatelessWidget {
  final LoopMode loopMode;
  final VoidCallback onTap;
  final double size;
  final Color? inactiveColor;

  const LoopModeButton({
    super.key,
    required this.loopMode,
    required this.onTap,
    this.size = 24,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (loopMode) {
      LoopMode.none => (Icons.repeat,     inactiveColor ?? AppColors.textPrimary),
      LoopMode.one  => (Icons.repeat_one, AppColors.accent),
      LoopMode.all  => (Icons.repeat,     AppColors.accent),
    };

    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: size),
    );
  }
}
