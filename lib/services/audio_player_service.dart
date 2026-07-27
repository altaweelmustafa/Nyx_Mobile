import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/mock_data.dart';

class AudioPlayerService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal() {
    _init();
  }

  // ── Internal state ─────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  MockTrack? _currentTrack;
  bool     _isPlaying = false;
  bool     _isShuffle = false;
  bool     _isRepeat  = false;
  Duration _position  = Duration.zero;
  Duration _duration  = Duration.zero;
  bool     _isLoading = false;

  // ── Public getters ─────────────────────────────────────────────────────────
  MockTrack? get currentTrack => _currentTrack;
  bool       get isPlaying    => _isPlaying;
  bool       get isShuffle    => _isShuffle;
  bool       get isRepeat     => _isRepeat;
  bool       get isLoading    => _isLoading;
  Duration   get position     => _position;
  Duration   get duration     => _duration;

  /// 0.0 to 1.0 progress fraction, safe against zero-duration
  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Formatted "m:ss" strings for UI timestamps
  String get positionLabel => _fmt(_position);
  String get durationLabel => _fmt(_duration);

  // ── Init ───────────────────────────────────────────────────────────────────
  void _init() {
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

    // Auto-repeat or stop at end of track
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_isRepeat) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          _player.seek(Duration.zero);
          _isPlaying = false;
          notifyListeners();
        }
      }
    });
  }

  // ── Public controls ────────────────────────────────────────────────────────

  /// Load and immediately play a track.
  /// If the same track is already loaded, just resumes.
  Future<void> play(MockTrack track) async {
    if (_currentTrack?.id == track.id && !_player.processingState.equals(ProcessingState.idle)) {
      await _player.play();
      return;
    }

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
    } catch (e) {
      _isLoading = false;
      debugPrint('AudioPlayerService.play() error: $e');
      notifyListeners();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else if (_currentTrack != null) {
      await _player.play();
    }
  }

  /// Seek using a 0.0–1.0 fraction of total duration (for the waveform scrubber)
  Future<void> seekToFraction(double fraction) async {
    if (_duration == Duration.zero) return;
    final ms = (fraction * _duration.inMilliseconds).round();
    await _player.seek(Duration(milliseconds: ms));
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
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
