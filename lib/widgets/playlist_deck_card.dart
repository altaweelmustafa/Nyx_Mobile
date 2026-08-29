import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/playlist.dart';
import 'track_thumbnail.dart';

/// A square playlist cover built from up to 4 of its tracks' thumbnails,
/// fanned out like a stacked deck of cards (Uno-style) so a playlist reads
/// as "a stack of songs" at a glance instead of looking like a single
/// track. Used on Home's Recommended row and in Search results -- the two
/// places playlists are surfaced outside Your Library.
class PlaylistDeckCard extends StatelessWidget {
  final Playlist playlist;
  final List<String?> thumbnails;
  final double size;
  final VoidCallback onTap;
  final bool showLabel;

  const PlaylistDeckCard({
    super.key,
    required this.playlist,
    required this.thumbnails,
    required this.onTap,
    this.size = 130,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final step = size * 0.046; // fan offset between stacked layers
    final layerSize = size - step * 3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  // Back-to-front so the frontmost (real) card ends up on
                  // top with the others peeking out bottom-right.
                  for (int layer = 3; layer >= 0; layer--)
                    Positioned(
                      left: layer * step,
                      top: layer * step,
                      child: Container(
                        width: layerSize,
                        height: layerSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size * 0.08),
                          border: layer > 0
                              ? Border.all(
                                  color: AppColors.background,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: TrackThumbnail(
                          size: layerSize,
                          assetPath: thumbnails.isNotEmpty
                              ? (layer < thumbnails.length
                                    ? thumbnails[layer]
                                    : thumbnails.first)
                              : null,
                          borderRadius: size * 0.08,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 8),
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Playlist',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
