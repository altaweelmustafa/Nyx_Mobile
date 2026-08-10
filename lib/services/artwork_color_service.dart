import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Extracts a dominant color from a track's cover art (asset or network
/// image) so backgrounds can be tinted to match, Spotify-style. Results are
/// cached in memory by path -- palette extraction decodes the full image,
/// so it's too slow to redo on every rebuild of the same track.
class ArtworkColorService {
  ArtworkColorService._();

  static final Map<String, Color?> _cache = {};

  static Future<Color?> extract(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (_cache.containsKey(path)) return _cache[path];

    try {
      final ImageProvider provider = path.startsWith('http://') || path.startsWith('https://')
          ? CachedNetworkImageProvider(path)
          : AssetImage(path);

      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(120, 120),
        maximumColorCount: 16,
      );

      final color = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color;
      _cache[path] = color;
      return color;
    } catch (_) {
      _cache[path] = null;
      return null;
    }
  }

  /// Darkens/desaturates an extracted color into a shade that's safe to use
  /// as a screen background behind light text -- a raw dominant color is
  /// often too bright or too saturated to read text on top of.
  static Color tuneForBackground(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness(hsl.lightness.clamp(0.14, 0.32))
        .withSaturation((hsl.saturation * 1.15).clamp(0.0, 0.65))
        .toColor();
  }
}
