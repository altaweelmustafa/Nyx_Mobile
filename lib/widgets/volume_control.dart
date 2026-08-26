import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

/// Desktop volume slider with a mute-toggle icon. Used by DesktopPlayerBar
/// and TrackViewScreen (desktop only) -- mobile relies on the OS volume
/// buttons instead.
class VolumeControl extends StatefulWidget {
  final double sliderWidth;
  final Color iconColor;
  final Color activeTrackColor;
  final Color inactiveTrackColor;

  const VolumeControl({
    super.key,
    this.sliderWidth = 90,
    this.iconColor = AppColors.textPrimary,
    this.activeTrackColor = AppColors.accent,
    this.inactiveTrackColor = AppColors.divider,
  });

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  // Remembers the level to restore to when un-muting, so tapping the icon
  // twice gets you back to where you were instead of jumping to 100%.
  double _preMuteVolume = 1.0;

  void _toggleMute(AudioPlayerService svc) {
    if (svc.volume > 0) {
      _preMuteVolume = svc.volume;
      svc.setVolume(0);
    } else {
      svc.setVolume(_preMuteVolume > 0 ? _preMuteVolume : 1.0);
    }
  }

  IconData _iconFor(double volume) {
    if (volume <= 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AudioPlayerService>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _toggleMute(svc),
          child: Icon(_iconFor(svc.volume), size: 18, color: widget.iconColor),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: widget.sliderWidth,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: widget.activeTrackColor,
              inactiveTrackColor: widget.inactiveTrackColor,
              thumbColor: widget.iconColor,
              overlayColor: widget.activeTrackColor.withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: svc.volume,
              onChanged: (v) => svc.setVolume(v),
            ),
          ),
        ),
      ],
    );
  }
}
