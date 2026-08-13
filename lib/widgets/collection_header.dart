import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'track_thumbnail.dart';

/// Header used by every single-collection screen (artist, playlist, liked
/// songs): a thumbnail, title + track count, and a circular play-all button.
/// Keeping this in one widget is what makes those screens look alike.
class CollectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? thumbnailPath;
  final double thumbnailBorderRadius;
  final VoidCallback? onPlayAll;

  const CollectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.thumbnailPath,
    this.thumbnailBorderRadius = 16,
    required this.onPlayAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          TrackThumbnail(
            size: 72,
            assetPath: thumbnailPath,
            borderRadius: thumbnailBorderRadius,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onPlayAll != null)
            GestureDetector(
              onTap: onPlayAll,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
