import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'audio_player_service.dart';

enum JamRole { none, host, client }

/// Dead simple listen-together over a tailnet: one device hosts a WebSocket
/// server and pushes its playback state, everyone else just mirrors it.
/// No bidirectional control, no reconnect logic -- the host DJs.
class JamService extends ChangeNotifier {
  static const port = 53289;

  final AudioPlayerService _player;
  JamService(this._player);

  JamRole _role = JamRole.none;
  JamRole get role => _role;

  String? _error;
  String? get error => _error;

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

  Future<bool> join(String address) async {
    try {
      final socket = await WebSocket.connect('ws://$address:$port')
          .timeout(const Duration(seconds: 6));
      _clientSocket = socket;
      _hostAddress = address;
      _role = JamRole.client;
      _error = null;
      notifyListeners();

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
