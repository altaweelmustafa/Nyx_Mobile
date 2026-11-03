import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Thumbnail extends StatelessWidget {
  final double size;
  final double borderRadius;
  final Widget? child;

  const Thumbnail({
    super.key,
    required this.size,
    this.borderRadius = 6,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.placeholder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}

class CircleThumbnail extends StatelessWidget {
  final double size;
  final String? imagePath; // local file path (saved avatar), or a URL on web

  const CircleThumbnail({super.key, required this.size, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: imagePath != null && imagePath!.startsWith('http')
            ? Image.network(
                imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.placeholder),
              )
            : imagePath != null
            ? Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.placeholder),
              )
            : const ColoredBox(color: AppColors.placeholder),
      ),
    );
  }
}
