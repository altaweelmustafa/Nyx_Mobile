import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_route_service.dart';
import '../theme/app_theme.dart';
import 'marquee_text.dart';

/// Shows the name + type icon of whatever Bluetooth audio device is
/// currently connected, or a muted "No bluetooth device" label when
/// nothing is. The label sits in a fixed-width box -- if a device name is
/// too long to fit, it auto-scrolls right to reveal the rest instead of
/// just truncating.
class BluetoothIndicator extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final Color color;
  final double nameWidth;
  final MainAxisAlignment alignment;

  const BluetoothIndicator({
    super.key,
    this.iconSize = 12,
    this.fontSize = 11,
    this.color = AppColors.accent,
    this.nameWidth = 120,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final device = context.watch<BluetoothRouteService>().currentDevice;
    final connected = device != null;
    final icon = device?.icon ?? Icons.bluetooth_disabled;
    final label = device?.name ?? 'No bluetooth device';
    final labelColor = connected ? color : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        Icon(icon, size: iconSize, color: labelColor),
        const SizedBox(width: 4),
        MarqueeText(
          text: label,
          width: nameWidth,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: fontSize,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
