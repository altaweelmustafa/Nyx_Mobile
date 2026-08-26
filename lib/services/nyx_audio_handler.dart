import 'dart:async';
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
  bool? _lastPlaying;
  bool? _lastLoading;
  DateTime? _lastBroadcastAt;
  Duration? _lastBroadcastPosition;

  // A plain headset/earbud remote button (wired or single-button Bluetooth)
  // only ever reports a generic "media" click, with no way to tell single
  // from double from triple -- so we count clicks ourselves within a short
  // window, matching the convention most earbuds' own inline mics assume:
  // 1 click = play/pause, 2 = next, 3+ = previous.
  int _clickCount = 0;
  Timer? _clickTimer;
  static const _clickWindow = Duration(milliseconds: 400);
  static const _seekStep = Duration(seconds: 10);

  NyxAudioHandler(this._service) {
    _service.addListener(_sync);
    _sync();
  }

  void _sync() {
    _maybeUpdateMediaItem();
    // AudioPlayerService.notifyListeners() fires on every position tick
    // (several times a second during playback); broadcasting a fresh
    // PlaybackState that often floods the platform channel and makes the
    // notification / in-app play-pause button lag. Only push a new one when
    // playing/loading changes, or the position jumped further than normal
    // playback would explain (a seek) -- audio_service extrapolates position
    // between updates from updatePosition + updateTime otherwise, so this
    // doesn't cost seek-bar accuracy.
    final stateChanged =
        _service.isPlaying != _lastPlaying || _service.isLoading != _lastLoading;
    if (!stateChanged && !_positionJumped()) return;
    _updatePlaybackState();
  }

  bool _positionJumped() {
    final at = _lastBroadcastAt;
    final pos = _lastBroadcastPosition;
    if (at == null || pos == null || _lastPlaying != true) return false;
    final expected = pos + DateTime.now().difference(at);
    return (_service.position - expected).abs() > const Duration(milliseconds: 1200);
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
    _lastPlaying = playing;
    _lastLoading = _service.isLoading;
    _lastBroadcastAt = DateTime.now();
    _lastBroadcastPosition = _service.position;
    playbackState.add(
      playbackState.value.copyWith(
        // Rewind/fast-forward ride along as expanded-notification-only
        // actions -- the compact indices below keep prev/play-pause/next as
        // the 3 buttons shown collapsed, same as before.
        controls: [
          MediaControl.rewind,
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.fastForward,
          MediaAction.rewind,
        },
        androidCompactActionIndices: const [1, 2, 3],
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
  Future<void> fastForward() => _service.seekBy(_seekStep);

  @override
  Future<void> rewind() => _service.seekBy(-_seekStep);

  /// A device that reports genuinely distinct next/previous buttons (some
  /// 3-button Bluetooth remotes) still gets those directly -- only a plain
  /// "media" click goes through the click-counting below.
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button != MediaButton.media) {
      return super.click(button);
    }

    _clickCount++;
    _clickTimer?.cancel();
    _clickTimer = Timer(_clickWindow, () {
      switch (_clickCount) {
        case 1:
          _service.togglePlayPause();
        case 2:
          _service.playNext();
        default: // 3 or more
          _service.playPrevious();
      }
      _clickCount = 0;
    });
  }

  @override
  Future<void> stop() async {
    await _service.pause();
    await super.stop();
  }
}
