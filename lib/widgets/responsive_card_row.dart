import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Lays out already-built card widgets as a horizontal-scrolling strip
/// below the desktop breakpoint -- preserving the app's existing phone
/// behavior exactly -- or a wrapping grid above it, so the extra width of
/// a desktop window gets used instead of staying a narrow scrolling lane.
/// The cards themselves ([children]) don't change between the two modes,
/// only the container that lays them out.
class ResponsiveCardRow extends StatelessWidget {
  final List<Widget> children;
  final double mobileHeight;
  final double spacing;

  const ResponsiveCardRow({
    super.key,
    required this.children,
    required this.mobileHeight,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    if (!context.isDesktop) {
      return SizedBox(
        height: mobileHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: children.length,
          separatorBuilder: (_, __) => SizedBox(width: spacing),
          itemBuilder: (_, i) => children[i],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(spacing: spacing, runSpacing: 16, children: children),
    );
  }
}
