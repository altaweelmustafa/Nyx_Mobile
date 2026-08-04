import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrackThumbnail extends StatelessWidget {
  final String? assetPath; // a bundled 'assets/...' path or a full http(s) URL
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
    final path = assetPath;
    Widget image;
    if (path == null) {
      image = _placeholder();
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      image = CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else {
      image = Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: image),
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
