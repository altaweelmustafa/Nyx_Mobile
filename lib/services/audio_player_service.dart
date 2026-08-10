import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../models/track.dart';
import '../repositories/track_repository.dart';

enum LoopMode { none, one, all }

class AudioPlayerService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal() {
    _init();
  }

  // ── Internal state ─────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();
  final _trackRepo = TrackRepository();
  final _rng = Random();

  Track? _currentTrack;
  bool      _isPlaying = false;
  bool      _isShuffle = false;
  LoopMode  _loopMode  = LoopMode.none;
  Duration  _position  = Duration.zero;
  Duration  _duration  = Duration.zero;
  bool      _isLoading = false;

  List<Track> _queue        = [];
  int             _currentIndex = -1;

  // Shuffle-bag: indices not yet played in the current pass through the
  // queue. Drained one at a time so every track plays once before any
  // repeats; refilled (excluding the just-finished track) once empty.
  List<int> _shuffleBag = [];

  // True while a track-to-track transition is in flight; blocks spurious completed events.
  bool _isAdvancing = false;

  // ── Public getters ─────────────────────────────────────────────────────────
  Track? get currentTrack => _currentTrack;
  bool       get isPlaying    => _isPlaying;
  bool       get isShuffle    => _isShuffle;
  LoopMode   get loopMode     => _loopMode;
  bool       get isLoading    => _isLoading;
  Duration   get position     => _position;
  Duration   get duration     => _duration;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String get positionLabel => _fmt(_position);
  String get durationLabel => _fmt(_duration);

  // ── Init ───────────────────────────────────────────────────────────────────
  void _init() {
    // Disable just_audio / media_kit internal looping — we manage the queue ourselves.
    _player.setLoopMode(ja.LoopMode.off);

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    _player.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onTrackCompleted();
      }
    });
  }

  void _onTrackCompleted() {
    if (_isAdvancing) return;

    switch (_loopMode) {
      case LoopMode.one:
        // Use just_audio's native single-track loop (seek + play avoids setUrl re-trigger).
        _player.seek(Duration.zero).then((_) => _player.play());

      case LoopMode.all:
        _isAdvancing = true;
        _advanceQueue(wrap: true).whenComplete(() => _isAdvancing = false);

      case LoopMode.none:
        if (_isShuffle || _currentIndex < _queue.length - 1) {
          _isAdvancing = true;
          _advanceQueue(wrap: false).whenComplete(() => _isAdvancing = false);
        } else {
          // End of queue — stop. Do NOT seek here: seeking on a completed player
          // can auto-restart playback on the media_kit backend.
          _isPlaying = false;
          notifyListeners();
        }
    }
  }

  // ── Public controls ────────────────────────────────────────────────────────

  Future<void> play(Track track) async {
    if (_currentTrack?.id == track.id && !_player.processingState.equals(ProcessingState.idle)) {
      await _player.play();
      return;
    }

    final existingIndex = _queue.indexWhere((t) => t.id == track.id);
    if (existingIndex == -1) {
      _queue = [track];
      _currentIndex = 0;
    } else {
      _currentIndex = existingIndex;
    }
    if (_isShuffle) _refillShuffleBag();

    await _loadAndPlay(track);
  }

  /// Set a full queue and start playing from [index].
  Future<void> playQueue(List<Track> tracks, int index) async {
    _queue = List.from(tracks);
    _currentIndex = index.clamp(0, tracks.length - 1);
    if (_isShuffle) _refillShuffleBag();
    await _loadAndPlay(_queue[_currentIndex]);
  }

  /// Skip forward — always wraps around to the start when on the last track.
  Future<void> playNext() => _advanceQueue(wrap: true);

  /// Skip backward — restarts current track if >3 s in, otherwise wraps to end.
  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prev = (_currentIndex - 1 + _queue.length) % _queue.length;
    _currentIndex = prev;
    await _loadAndPlay(_queue[_currentIndex]);
  }

  Future<void> _advanceQueue({required bool wrap}) async {
    if (_queue.isEmpty) return;
    int next;

    if (_isShuffle) {
      if (_queue.length <= 1) {
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      }
      if (_shuffleBag.isEmpty) {
        // Full pass through the queue just completed.
        if (!wrap) {
          // Mirrors the non-shuffle end-of-queue stop below -- don't seek
          // here, seeking on a completed player can auto-restart playback
          // on the media_kit backend.
          _isPlaying = false;
          notifyListeners();
          return;
        }
        _refillShuffleBag();
      }
      next = _shuffleBag.removeLast();
    } else {
      next = _currentIndex + 1;
      if (next >= _queue.length) {
        if (!wrap) return;
        next = 0;
      }
    }

    if (next == _currentIndex) {
      // 1-track queue wrapping to itself: seek instead of reloading to avoid
      // setUrl triggering another completed event on the media_kit backend.
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    _currentIndex = next;
    await _loadAndPlay(_queue[_currentIndex]);
  }

  Future<void> _loadAndPlay(Track track) async {
    _currentTrack = track;
    _isLoading    = true;
    _position     = Duration.zero;
    _duration     = Duration.zero;
    notifyListeners();

    try {
      await _player.setUrl(track.audioUrl);
      _isLoading = false;
      notifyListeners();
      await _player.play();
      _trackRepo.incrementPlayCount(track.id);
    } catch (e) {
      _isLoading = false;
      debugPrint('AudioPlayerService._loadAndPlay() error: $e');
      notifyListeners();
    }
  }

  /// Applies a playback snapshot received from a Jam host: loads the same
  /// track by URL if it isn't already playing, corrects drift past a small
  /// threshold, and mirrors play/pause. Used only on the follower side of a
  /// Jam session -- the track doesn't need to exist in the local DB.
  Future<void> playRemote({
    required String title,
    required String artist,
    required String audioUrl,
    String? thumbnailPath,
    required bool isPlaying,
    required int positionMs,
  }) async {
    if (_currentTrack?.audioUrl != audioUrl) {
      final remoteTrack = Track(
        id: 'jam',
        title: title,
        artist: artist,
        song: title,
        audioUrl: audioUrl,
        thumbnailPath: thumbnailPath,
      );
      _queue = [remoteTrack];
      _currentIndex = 0;
      await _loadAndPlay(remoteTrack);
    }

    final drift = Duration(milliseconds: positionMs) - _position;
    if (drift.inMilliseconds.abs() > 1500) {
      await _player.seek(Duration(milliseconds: positionMs));
    }

    if (isPlaying && !_isPlaying) {
      await _player.play();
    } else if (!isPlaying && _isPlaying) {
      await _player.pause();
    }
  }

  Future<void> pause() => _player.pause();

  /// Unconditionally resumes/starts playback of the current track (a no-op
  /// if nothing is loaded or it's already playing). Used by togglePlayPause
  /// and by the Android media-notification / lock-screen "play" control.
  Future<void> resume() async {
    if (_isPlaying || _currentTrack == null) return;
    // If we're at the end of the track (completed state), restart from the beginning.
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> seekToFraction(double fraction) async {
    if (_duration == Duration.zero) return;
    final ms = (fraction * _duration.inMilliseconds).round();
    await seek(Duration(milliseconds: ms));
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      _refillShuffleBag();
    } else {
      _shuffleBag = [];
    }
    notifyListeners();
  }

  /// Rebuilds the shuffle-bag with every queue index except the currently
  /// playing one, in a fresh random order.
  void _refillShuffleBag() {
    _shuffleBag = [for (int i = 0; i < _queue.length; i++) if (i != _currentIndex) i];
    _shuffleBag.shuffle(_rng);
  }

  /// Cycles: none → one → all → none
  void toggleRepeat() {
    _loopMode = switch (_loopMode) {
      LoopMode.none => LoopMode.one,
      LoopMode.one  => LoopMode.all,
      LoopMode.all  => LoopMode.none,
    };
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

extension _ProcStateEq on ProcessingState {
  bool equals(ProcessingState other) => this == other;
}
