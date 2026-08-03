import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/track_view_screen.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import 'mini_player.dart';

/// A Scaffold that docks the compact [MiniPlayer] to the bottom of the
/// screen whenever a track is loaded, so playback controls stay reachable
/// everywhere in the app (not just the three shell tabs). Renders nothing
/// extra when there's no current track -- MiniPlayer collapses to zero
/// height itself.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool showMiniPlayer;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.showMiniPlayer = true,
  });

  void _openPlayer(BuildContext context) {
    final track = context.read<AudioPlayerService>().currentTrack;
    if (track == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TrackViewScreen(track: track)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: appBar,
      body: body,
      bottomNavigationBar: showMiniPlayer
          ? SafeArea(
              top: false,
              child: MiniPlayer(onTap: () => _openPlayer(context)),
            )
          : null,
    );
  }
}
