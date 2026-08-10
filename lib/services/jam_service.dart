import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_player_service.dart';

enum JamRole { none, host, client }

/// A previously joined roll host, kept around for quick rejoin.
class RecentRoll {
  final String username;
  final String address;

  const RecentRoll({required this.username, required this.address});

  Map<String, Object?> toJson() => {'username': username, 'address': address};

  factory RecentRoll.fromJson(Map<String, Object?> json) => RecentRoll(
        username: json['username'] as String? ?? '',
        address: json['address'] as String,
      );
}

/// Dead simple listen-together over a tailnet: one device hosts a WebSocket
/// server and pushes its playback state, everyone else just mirrors it.
/// No bidirectional control, no reconnect logic -- the host DJs.
class JamService extends ChangeNotifier {
  static const port = 53289;
  static const _recentsKey = 'jam_recent_rolls';
  static const _maxRecents = 5;

  final AudioPlayerService _player;
  JamService(this._player) {
    _loadRecents();
  }

  JamRole _role = JamRole.none;
  JamRole get role => _role;

  String? _error;
  String? get error => _error;

  List<RecentRoll> _recents = [];
  List<RecentRoll> get recents => List.unmodifiable(_recents);

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentsKey) ?? [];
    _recents = raw
        .map((s) => RecentRoll.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> _saveRecent(String address, String username) async {
    if (username.isEmpty) return;
    final entry = RecentRoll(username: username, address: address);
    _recents.removeWhere((r) => r.address == address);
    _recents.insert(0, entry);
    if (_recents.length > _maxRecents) {
      _recents = _recents.sublist(0, _maxRecents);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentsKey,
      _recents.map((r) => jsonEncode(r.toJson())).toList(),
    );
    notifyListeners();
  }

  // ── Host state ─────────────────────────────────────────────────────────
  HttpServer? _server;
  final Set<WebSocket> _listeners = {};
  int get listenerCount => _listeners.length;

  // ── Client state ───────────────────────────────────────────────────────
  WebSocket? _clientSocket;
  String? _hostAddress;
  String? get hostAddress => _hostAddress;

  Future<bool> startHosting() async {
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server = server;
      server.listen((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        _listeners.add(socket);
        notifyListeners();
        _sendStateTo(socket);
        socket.listen(
          (_) {}, // followers are receive-only in this simple model
          onDone: () {
            _listeners.remove(socket);
            notifyListeners();
          },
          onError: (_) {
            _listeners.remove(socket);
            notifyListeners();
          },
        );
      });

      _role = JamRole.host;
      _error = null;
      _player.addListener(_broadcastState);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not start jam: $e';
      notifyListeners();
      return false;
    }
  }

  Map<String, Object?>? _snapshot() {
    final track = _player.currentTrack;
    if (track == null) return null;
    return {
      'title': track.title,
      'artist': track.artist,
      'audioUrl': track.audioUrl,
      'thumbnailPath': track.thumbnailPath,
      'isPlaying': _player.isPlaying,
      'positionMs': _player.position.inMilliseconds,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void _broadcastState() {
    final snapshot = _snapshot();
    if (snapshot == null || _listeners.isEmpty) return;
    final msg = jsonEncode(snapshot);
    for (final socket in _listeners) {
      socket.add(msg);
    }
  }

  void _sendStateTo(WebSocket socket) {
    final snapshot = _snapshot();
    if (snapshot == null) return;
    socket.add(jsonEncode(snapshot));
  }

  Future<bool> join(String address, {String username = ''}) async {
    try {
      final socket = await WebSocket.connect('ws://$address:$port')
          .timeout(const Duration(seconds: 6));
      _clientSocket = socket;
      _hostAddress = address;
      _role = JamRole.client;
      _error = null;
      notifyListeners();
      unawaited(_saveRecent(address, username.trim()));

      socket.listen(
        _onHostMessage,
        onDone: disconnect,
        onError: (_) {
          _error = 'Connection to host lost';
          disconnect();
        },
      );
      return true;
    } catch (e) {
      _error = 'Could not join jam: $e';
      notifyListeners();
      return false;
    }
  }

  void _onHostMessage(dynamic raw) {
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    final sentAt = data['ts'] as int;
    final latencyMs = DateTime.now().millisecondsSinceEpoch - sentAt;
    final isPlaying = data['isPlaying'] as bool;
    _player.playRemote(
      title: data['title'] as String,
      artist: data['artist'] as String,
      audioUrl: data['audioUrl'] as String,
      thumbnailPath: data['thumbnailPath'] as String?,
      isPlaying: isPlaying,
      positionMs: (data['positionMs'] as int) + (isPlaying ? latencyMs : 0),
    );
  }

  /// Stops hosting or leaves whichever jam is currently active.
  Future<void> disconnect() async {
    if (_role == JamRole.host) {
      _player.removeListener(_broadcastState);
      for (final socket in _listeners) {
        await socket.close();
      }
      _listeners.clear();
      await _server?.close(force: true);
      _server = null;
    }

    await _clientSocket?.close();
    _clientSocket = null;
    _hostAddress = null;
    _role = JamRole.none;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
