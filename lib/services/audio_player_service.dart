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

  // True only when the current queue came from a user-created playlist (or
  // Liked Songs). Only in that context does reaching the end with looping
  // off actually stop playback -- every other listening context (Recommended,
  // an artist, search, Most Played, ...) keeps the music going indefinitely.
  bool _isPersonalPlaylist = false;

  List<Track> _queue        = [];
  int             _currentIndex = -1;

  // Shuffle order: a fixed permutation of _queue indices for the current
  // pass, with _shufflePos pointing at where _currentIndex sits within it.
  // Unlike re-rolling a random index on every skip, this is generated once
  // per pass and walked forward/backward -- so "previous" during shuffle
  // actually retraces shuffled play history instead of landing on an
  // unrelated track, and repeated next/prev never reshuffles mid-pass.
  List<int> _shuffleOrder = [];
  int _shufflePos = -1;

  // True while a track-to-track transition is in flight; blocks spurious completed events.
  bool _isAdvancing = false;

  double _volume = 1.0;

  // ── Public getters ─────────────────────────────────────────────────────────
  Track? get currentTrack => _currentTrack;
  bool       get isPlaying    => _isPlaying;
  bool       get isShuffle    => _isShuffle;
  LoopMode   get loopMode     => _loopMode;
  bool       get isLoading    => _isLoading;
  Duration   get position     => _position;
  Duration   get duration     => _duration;
  double     get volume       => _volume;

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
        final atEnd = _isShuffle
            ? _shufflePos >= _shuffleOrder.length - 1
            : _currentIndex >= _queue.length - 1;
        if (!atEnd) {
          _isAdvancing = true;
          _advanceQueue(wrap: false).whenComplete(() => _isAdvancing = false);
        } else if (_isPersonalPlaylist) {
          // A personal playlist with looping off -- respect the stop. Do NOT
          // seek here: seeking on a completed player can auto-restart
          // playback on the media_kit backend.
          _isPlaying = false;
          notifyListeners();
        } else {
          // Radio-style context (Recommended, an artist, search, ...) --
          // never go silent, keep the music going.
          _isAdvancing = true;
          _autoContinue().whenComplete(() => _isAdvancing = false);
        }
    }
  }

  /// Extends the queue with fresh random tracks and plays the next one --
  /// used when a non-personal listening context runs out of tracks so
  /// playback never just stops.
  Future<void> _autoContinue() async {
    final excludeIds = _queue.map((t) => t.id).toSet();
    var more = await _trackRepo.getAutoplaySuggestions(excludeIds, 15);
    if (more.isEmpty && _currentTrack != null) {
      // The whole library is already queued -- allow repeats rather than
      // stop playback.
      more = await _trackRepo.getAutoplaySuggestions({_currentTrack!.id}, 15);
    }
    if (more.isEmpty) {
      _isPlaying = false;
      notifyListeners();
      return;
    }

    final insertedAt = _queue.length;
    _queue.addAll(more);
    if (_isShuffle) {
      // Extend the current shuffled pass rather than starting a new one --
      // the new tracks join the tail of the order, freshly shuffled among
      // themselves, and playback moves one step forward into them.
      final newIndices = [for (int i = 0; i < more.length; i++) insertedAt + i];
      newIndices.shuffle(_rng);
      _shuffleOrder.addAll(newIndices);
      _shufflePos++;
      _currentIndex = _shuffleOrder[_shufflePos];
    } else {
      _currentIndex = insertedAt;
    }
    await _loadAndPlay(_queue[_currentIndex]);
  }

  // ── Public controls ────────────────────────────────────────────────────────

  Future<void> play(Track track) async {
    if (_currentTrack?.id == track.id && !_player.processingState.equals(ProcessingState.idle)) {
      await _player.play();
      return;
    }

    _isPersonalPlaylist = false;
    final existingIndex = _queue.indexWhere((t) => t.id == track.id);
    if (existingIndex == -1) {
      _queue = [track];
      _currentIndex = 0;
    } else {
      _currentIndex = existingIndex;
    }
    if (_isShuffle) _startNewShufflePass();

    await _loadAndPlay(track);
  }

  /// Set a full queue and start playing from [index]. [isPersonalPlaylist]
  /// marks a user-created playlist (or Liked Songs) -- the only context
  /// where reaching the end with looping off actually stops playback.
  Future<void> playQueue(
    List<Track> tracks,
    int index, {
    bool isPersonalPlaylist = false,
  }) async {
    _isPersonalPlaylist = isPersonalPlaylist;
    _queue = List.from(tracks);
    _currentIndex = index.clamp(0, tracks.length - 1);
    if (_isShuffle) _startNewShufflePass();
    await _loadAndPlay(_queue[_currentIndex]);
  }

  /// Skip forward — always wraps around to the start when on the last track.
  Future<void> playNext() => _advanceQueue(wrap: true);

  /// Skip backward — restarts current track if >3 s in, otherwise steps back
  /// one track. In shuffle mode this retraces the shuffled order (the same
  /// sequence "next" walks forward through) rather than the queue's
  /// original order, so it always lands on whatever actually played before.
  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_isShuffle && _shuffleOrder.isNotEmpty) {
      if (_shuffleOrder.length <= 1) {
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      }
      _shufflePos = _shufflePos <= 0 ? _shuffleOrder.length - 1 : _shufflePos - 1;
      _currentIndex = _shuffleOrder[_shufflePos];
      await _loadAndPlay(_queue[_currentIndex]);
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
      if (_shufflePos >= _shuffleOrder.length - 1) {
        // Full pass through the shuffled order just completed.
        if (!wrap) {
          // Mirrors the non-shuffle end-of-queue stop below -- don't seek
          // here, seeking on a completed player can auto-restart playback
          // on the media_kit backend.
          _isPlaying = false;
          notifyListeners();
          return;
        }
        _reshuffleForNewPass();
      } else {
        _shufflePos++;
      }
      next = _shuffleOrder[_shufflePos];
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

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      // A Bluetooth route flap (A2DP disconnect/reconnect) can throw here
      // on Android mid-transition. Don't let it die silently -- resync
      // _isPlaying from the player's actual state so the UI doesn't get
      // stuck showing "playing" when the tap effectively did nothing.
      debugPrint('AudioPlayerService.pause() error: $e');
      _isPlaying = _player.playing;
      notifyListeners();
    }
  }

  /// Unconditionally resumes/starts playback of the current track (a no-op
  /// if nothing is loaded or it's already playing). Used by togglePlayPause
  /// and by the Android media-notification / lock-screen "play" control.
  Future<void> resume() async {
    if (_isPlaying || _currentTrack == null) return;
    try {
      // If we're at the end of the track (completed state), restart from the beginning.
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (e) {
      debugPrint('AudioPlayerService.resume() error: $e');
      _isPlaying = _player.playing;
      notifyListeners();
    }
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

  /// Seeks relative to the current position, clamped to the track's bounds
  /// -- shared by the desktop left/right-arrow shortcuts and the Android
  /// notification/lock-screen rewind/fast-forward buttons.
  Future<void> seekBy(Duration delta) async {
    var target = _position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    await seek(target);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  // Remembers the level to restore to when un-muting, so muting then
  // un-muting (via the volume icon or the desktop M shortcut) gets back to
  // where you were instead of jumping to 100%.
  double _preMuteVolume = 1.0;

  Future<void> toggleMute() async {
    if (_volume > 0) {
      _preMuteVolume = _volume;
      await setVolume(0);
    } else {
      await setVolume(_preMuteVolume > 0 ? _preMuteVolume : 1.0);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      _startNewShufflePass();
    } else {
      _shuffleOrder = [];
      _shufflePos = -1;
    }
    notifyListeners();
  }

  /// Builds a fresh shuffled order for the whole queue, keeping whatever's
  /// currently playing (_currentIndex) at the front so turning shuffle on
  /// mid-track -- or starting a new queue with shuffle already on -- never
  /// jumps to a different track. "Next"/"previous" then just walk this
  /// fixed order forward/backward, so a full playlist worth of tracks each
  /// play exactly once per pass and previous always retraces real history.
  void _startNewShufflePass() {
    final rest = [for (int i = 0; i < _queue.length; i++) if (i != _currentIndex) i];
    rest.shuffle(_rng);
    _shuffleOrder = (_currentIndex >= 0 && _currentIndex < _queue.length)
        ? [_currentIndex, ...rest]
        : rest;
    _shufflePos = 0;
  }

  /// Reshuffles for a new lap once every track in the current pass has been
  /// played (called from mid-playback, not track-start) -- avoids
  /// immediately replaying the track that just finished back-to-back.
  void _reshuffleForNewPass() {
    final indices = [for (int i = 0; i < _queue.length; i++) i];
    indices.shuffle(_rng);
    if (indices.length > 1 && indices.first == _currentIndex) {
      final tmp = indices[0];
      indices[0] = indices[1];
      indices[1] = tmp;
    }
    _shuffleOrder = indices;
    _shufflePos = 0;
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
