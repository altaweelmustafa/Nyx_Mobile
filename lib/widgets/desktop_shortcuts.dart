import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show navigatorKey;
import '../screens/lyrics_screen.dart';
import '../services/audio_player_service.dart';

/// Desktop keyboard shortcuts for playback, wrapped around the whole app
/// (see BragerApp) so they work from anywhere. Flutter's key event dispatch
/// walks from whatever's currently focused up toward the root, so a focused
/// text field (search, a rename dialog, ...) still gets first crack at
/// every key -- these only fire once nothing more specific has claimed it.
class DesktopShortcuts extends StatelessWidget {
  final Widget child;

  const DesktopShortcuts({super.key, required this.child});

  void _openLyrics() {
    final track = AudioPlayerService().currentTrack;
    if (track == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => LyricsScreen(track: track)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = AudioPlayerService();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): svc.togglePlayPause,
        // Shift+Period/Comma as a SingleActivator doesn't reliably match on
        // Linux -- GTK reports the shifted keyval ('>'/'<') as its own
        // logical key rather than "period/comma + shift", so the modifier
        // check never passes. Matching the produced character directly
        // sidesteps that (and is the platform-agnostic way to bind a
        // shifted symbol per Flutter's own docs on SingleActivator).
        const CharacterActivator('>'): svc.playNext,
        const CharacterActivator('<'): svc.playPrevious,
        const SingleActivator(LogicalKeyboardKey.keyL, shift: true):
            svc.toggleRepeat,
        const SingleActivator(LogicalKeyboardKey.keyS, shift: true):
            svc.toggleShuffle,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _openLyrics,
        // Seek ±10s -- mirrors the fast-forward/rewind buttons now on the
        // Android lock-screen/notification, so "skip a few seconds" means
        // the same thing on both platforms.
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            svc.seekBy(const Duration(seconds: 10)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            svc.seekBy(const Duration(seconds: -10)),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            svc.setVolume(svc.volume + 0.05),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            svc.setVolume(svc.volume - 0.05),
        const SingleActivator(LogicalKeyboardKey.keyM): svc.toggleMute,
      },
      child: child,
    );
  }
}
