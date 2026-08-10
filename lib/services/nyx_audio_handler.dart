import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_player_service.dart';

/// Bridges [AudioPlayerService] to Android's media-notification / lock-screen
/// controls via audio_service, so playback survives the app being backgrounded
/// or the screen locking. [AudioPlayerService] stays the single source of
/// truth for playback; this handler only mirrors its state out to the OS and
/// forwards OS-originated commands (notification taps, headset buttons) back
/// into it.
class NyxAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayerService _service;

  String? _mediaItemTrackId;
  Duration? _mediaItemDuration;

  NyxAudioHandler(this._service) {
    _service.addListener(_sync);
    _sync();
  }

  void _sync() {
    _maybeUpdateMediaItem();
    _updatePlaybackState();
  }

  Future<void> _maybeUpdateMediaItem() async {
    final track = _service.currentTrack;
    if (track == null) {
      if (_mediaItemTrackId != null) {
        _mediaItemTrackId = null;
        _mediaItemDuration = null;
        mediaItem.add(null);
      }
      return;
    }

    final duration = _service.duration == Duration.zero
        ? null
        : _service.duration;
    if (track.id == _mediaItemTrackId && duration == _mediaItemDuration) {
      return;
    }
    _mediaItemTrackId = track.id;
    _mediaItemDuration = duration;

    final artUri = await _resolveArt(track.thumbnailPath);
    // The track may have changed again while art was resolving.
    if (_service.currentTrack?.id != track.id) return;

    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        duration: duration,
        artUri: artUri,
      ),
    );
  }

  void _updatePlaybackState() {
    final playing = _service.isPlaying;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        playing: playing,
        processingState: _service.isLoading
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        updatePosition: _service.position,
      ),
    );
  }

  String? _artCacheKeyPath;
  Uri? _artCacheKeyUri;

  /// The Android notification/lock-screen only render art from a local file
  /// (or content://) URI, not http(s) or Flutter asset paths -- so bundled
  /// art gets copied from the asset bundle and remote art gets downloaded,
  /// both into a cache file we can hand back as a file:// URI.
  Future<Uri?> _resolveArt(String? path) async {
    if (path == null) return null;
    if (path == _artCacheKeyPath) return _artCacheKeyUri;

    try {
      final dir = await getTemporaryDirectory();
      final name = 'nyx_art_${path.hashCode.toRadixString(16)}.img';
      final file = File(p.join(dir.path, name));

      if (!await file.exists()) {
        if (path.startsWith('http://') || path.startsWith('https://')) {
          final response = await Dio().get<List<int>>(
            path,
            options: Options(responseType: ResponseType.bytes),
          );
          await file.writeAsBytes(response.data!);
        } else {
          final data = await rootBundle.load(path);
          await file.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        }
      }

      _artCacheKeyPath = path;
      _artCacheKeyUri = Uri.file(file.path);
      return _artCacheKeyUri;
    } catch (_) {
      return null;
    }
  }

  // ── OS-originated commands ─────────────────────────────────────────────
  @override
  Future<void> play() => _service.resume();

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> seek(Duration position) => _service.seek(position);

  @override
  Future<void> skipToNext() => _service.playNext();

  @override
  Future<void> skipToPrevious() => _service.playPrevious();

  @override
  Future<void> stop() async {
    await _service.pause();
    await super.stop();
  }
}
