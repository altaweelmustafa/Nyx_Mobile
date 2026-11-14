import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import 'audio_player_service.dart';

/// Shows "Listening to Nyx" with the current track on your Snack profile.
///
/// Snack is the presence layer: Nyx reports what's playing to Snack's
/// `POST /api/activity` with the user's link key (Snack → Settings →
/// Connections), on every track/play-state change plus a 30 s heartbeat.
/// Snack drops the activity ~90 s after the last report, so a killed app
/// clears itself. Pausing clears it right away, like Spotify on Discord.
///
/// Works on every platform (plain HTTPS, Snack allows CORS on that route).
/// The key lives in SharedPreferences, deliberately not in the SQLite
/// library: scripts/publish_library.sh copies that DB onto the server where
/// anyone on the tailnet could download it.
class SnackPresenceService {
  SnackPresenceService._();
  static final instance = SnackPresenceService._();

  static const defaultUrl = 'https://debian-hp.tail7a7ffc.ts.net:8443';
  static const _keyPref = 'snack_link_key';
  static const _urlPref = 'snack_url';
  static const _heartbeat = Duration(seconds: 30);

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    // Let us read 401s instead of throwing on them.
    validateStatus: (_) => true,
  ));

  AudioPlayerService? _player;
  String? _key;
  String _url = defaultUrl;
  Timer? _timer;
  String? _lastTrackId;
  bool _lastPlaying = false;
  Duration _lastPos = Duration.zero;
  Duration _lastDur = Duration.zero;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _shown = false;

  String? get linkKey => _key;
  String get url => _url;
  bool get isLinked => _key != null;

  Future<void> start(AudioPlayerService player) async {
    _player = player;
    final prefs = await SharedPreferences.getInstance();
    _key = prefs.getString(_keyPref);
    _url = prefs.getString(_urlPref) ?? defaultUrl;
    player.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  /// Checks the key against Snack, then saves it. Returns an error message,
  /// or null on success.
  Future<String?> link(String key, String url) async {
    key = key.trim();
    url = url.trim().isEmpty ? defaultUrl : url.trim().replaceAll(RegExp(r'/+$'), '');
    final status = await _post({'clear': true}, key: key, url: url);
    if (status == null) return "Couldn't reach Snack at $url. Are you on the tailnet?";
    if (status == 401) return "Snack doesn't know that key.";
    if (status != 204) return 'Snack responded $status.';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key);
    await prefs.setString(_urlPref, url);
    _key = key;
    _url = url;
    _shown = false;
    _lastTrackId = null; // force a fresh report
    _onPlayerChanged();
    return null;
  }

  Future<void> unlink() async {
    if (_key != null) await _post({'clear': true});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPref);
    _key = null;
    _shown = false;
    _timer?.cancel();
    _timer = null;
  }

  void _onPlayerChanged() {
    final p = _player;
    if (p == null || _key == null) return;
    final track = p.currentTrack;
    final playing = p.isPlaying && track != null;
    final changed = track?.id != _lastTrackId || playing != _lastPlaying;

    // A seek: the position moved much further than the clock did.
    var seeked = false;
    if (!changed && playing) {
      final expected = _lastPos + DateTime.now().difference(_lastSent);
      seeked = (p.position - expected).inSeconds.abs() > 5;
      // The duration usually arrives just after playback starts.
      if (_lastDur == Duration.zero && p.duration > Duration.zero) seeked = true;
    }
    if (!changed && !seeked) return;

    _lastTrackId = track?.id;
    _lastPlaying = playing;

    if (playing) {
      _report(track);
      _timer ??= Timer.periodic(_heartbeat, (_) => _report(_player?.currentTrack));
    } else {
      _timer?.cancel();
      _timer = null;
      if (_shown) {
        _shown = false;
        _post({'clear': true});
      }
    }
  }

  void _report(Track? track) {
    final p = _player;
    if (p == null || track == null || !p.isPlaying) return;
    _lastPos = p.position;
    _lastDur = p.duration;
    _lastSent = DateTime.now();
    _shown = true;
    _post({
      'title': track.title,
      'subtitle': track.artist,
      'art': artRef(track.thumbnailPath),
      'pos': p.position.inMilliseconds / 1000,
      'dur': p.duration.inMilliseconds / 1000,
      'playing': true,
    });
  }

  /// Snack fetches cover art itself from orc (`nyx:/assets/...`): browsers
  /// can't load orc's plain-HTTP URLs inside Snack's HTTPS page.
  @visibleForTesting
  static String? artRef(String? thumb) {
    if (thumb == null || !thumb.startsWith('http')) return null;
    final path = Uri.tryParse(thumb)?.path ?? '';
    final i = path.indexOf('/assets/');
    return i < 0 ? null : 'nyx:${path.substring(i)}';
  }

  /// Returns the HTTP status, or null if Snack couldn't be reached.
  Future<int?> _post(Map<String, Object?> body, {String? key, String? url}) async {
    key ??= _key;
    if (key == null) return null;
    try {
      final r = await _dio.post<Object?>(
        '${url ?? _url}/api/activity',
        data: {'source': 'nyx', ...body},
        options: Options(headers: {'Authorization': 'Bearer $key'}, contentType: 'application/json'),
      );
      return r.statusCode;
    } catch (e) {
      debugPrint('SnackPresenceService: $e');
      return null;
    }
  }
}
