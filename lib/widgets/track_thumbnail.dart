import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrackThumbnail extends StatelessWidget {
  final String? assetPath;
  final double size;
  final double borderRadius;

  const TrackThumbnail({
    super.key,
    required this.size,
    this.assetPath,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: assetPath != null
            ? Image.asset(
                assetPath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.placeholder,
        child: Center(
          child: Icon(
            Icons.music_note,
            color: AppColors.background.withOpacity(0.4),
            size: size * 0.4,
          ),
        ),
      );
}
