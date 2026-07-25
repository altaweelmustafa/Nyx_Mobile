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

  const CircleThumbnail({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.placeholder,
        shape: BoxShape.circle,
      ),
    );
  }
}
