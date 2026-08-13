import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../screens/track_view_screen.dart';
import '../services/audio_player_service.dart';

/// Standard tap behavior for a track row, shared by every track list in the
/// app: if this exact track is already playing, open the full player;
/// otherwise just start it playing (queue = [tracks], starting at [index])
/// without navigating away, so browsing a list doesn't keep booting you out
/// of it. Use the mini player to open the full view instead.
void handleTrackTap(
  BuildContext context,
  List<Track> tracks,
  int index, {
  bool isPersonalPlaylist = false,
}) {
  final svc = context.read<AudioPlayerService>();
  final track = tracks[index];
  if (svc.isPlaying && svc.currentTrack?.id == track.id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackViewScreen(track: track)),
    );
    return;
  }
  svc.playQueue(tracks, index, isPersonalPlaylist: isPersonalPlaylist);
}
