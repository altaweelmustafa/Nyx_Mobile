import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/track.dart';
import 'audio_player_service.dart';

/// Mirrors the currently playing track onto Discord's Rich Presence (the
/// "Playing brager -- Song Title" line on your profile), by speaking
/// Discord's local IPC protocol directly to the Discord desktop client's
/// socket -- the same channel games and apps like VS Code use, not the
/// Spotify-style server-to-server "Connections" integration (that one's a
/// closed partnership; there's no public API for it).
///
/// Desktop-only by nature: the socket only exists where a Discord desktop
/// client is running (Linux/macOS via a Unix domain socket; Windows would
/// need a named pipe, not implemented here). There is no equivalent local
/// channel on Android/iOS, so this service is only ever constructed behind
/// main.dart's `_isDesktopPlatform` check and is a deliberate no-op on
/// Windows for now (falls through _connect with nothing to try).
class DiscordPresenceService {
  DiscordPresenceService(this._player, {required this.clientId});

  final AudioPlayerService _player;
  final String clientId;

  Socket? _socket;
  bool _connecting = false;
  bool _ready = false;
  Timer? _reconnectTimer;
  final _incoming = BytesBuilder();

  String? _lastTrackId;
  bool _lastPlaying = false;
  int _nonce = 0;

  void start() {
    _player.addListener(_onPlayerChanged);
    _connect();
  }

  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _reconnectTimer?.cancel();
    _socket?.destroy();
  }

  void _onPlayerChanged() => _pushActivity(force: false);

  /// Test-only entry point that exercises the same activity-building/IPC-send
  /// path as a real player-driven update, without needing a working
  /// just_audio plugin channel underneath AudioPlayerService (unavailable in
  /// a headless `flutter test` run).
  @visibleForTesting
  void debugPushActivity(Track? track, {required bool isPlaying, Duration position = Duration.zero}) {
    _lastTrackId = track?.id;
    _lastPlaying = isPlaying;
    _setActivity(track, isPlaying, position);
  }

  /// [force] bypasses the dedupe check below -- used right after the IPC
  /// handshake completes, to flush whatever's already playing even though,
  /// as far as _lastTrackId/_lastPlaying are concerned, "nothing changed"
  /// (nothing had been sent yet at all).
  void _pushActivity({required bool force}) {
    final track = _player.currentTrack;
    final trackChanged = track?.id != _lastTrackId;
    final playingChanged = _player.isPlaying != _lastPlaying;
    if (!force && !trackChanged && !playingChanged) return; // ignore position/duration ticks

    _lastTrackId = track?.id;
    _lastPlaying = _player.isPlaying;
    _setActivity(track, _player.isPlaying, _player.position);
  }

  // ── Connection ─────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (_connecting || _socket != null) return;
    if (!(Platform.isLinux || Platform.isMacOS)) {
      debugPrint('DiscordPresenceService: unsupported platform, not attempting to connect.');
      return; // Windows named pipes: not implemented
    }

    _connecting = true;
    final tried = <String>[];
    try {
      for (final dir in _candidateDirs()) {
        for (var i = 0; i < 10; i++) {
          final path = '$dir/discord-ipc-$i';
          tried.add(path);
          try {
            final socket = await Socket.connect(
              InternetAddress(path, type: InternetAddressType.unix),
              0,
            );
            _socket = socket;
            _ready = false;
            debugPrint('DiscordPresenceService: connected at $path, sending handshake.');
            socket.listen(_onData, onDone: _onDisconnected, onError: (_) => _onDisconnected());
            _sendHandshake();
            return;
          } catch (_) {
            // that index/dir has no listener -- try the next one
          }
        }
      }
      debugPrint(
        'DiscordPresenceService: no Discord IPC socket found. Tried: ${tried.join(', ')}',
      );
    } finally {
      _connecting = false;
      // Discord wasn't running (or hadn't opened its IPC socket yet) -- keep
      // trying periodically rather than giving up for the rest of the session.
      if (_socket == null) {
        _reconnectTimer ??= Timer.periodic(const Duration(seconds: 20), (_) => _connect());
      }
    }
  }

  /// Directories Discord's desktop client is known to create its IPC socket
  /// in, in the order it tries them itself -- plus the sandboxed variants
  /// used by Linux's Snap (`snap.discord/`) and Flatpak
  /// (`app/com.discordapp.Discord/`) packages, each of which nests the
  /// socket under an extra path segment inside the runtime dir.
  List<String> _candidateDirs() {
    final env = Platform.environment;
    final bases = [
      env['XDG_RUNTIME_DIR'],
      env['TMPDIR'],
      env['TMP'],
      env['TEMP'],
      '/tmp',
    ].whereType<String>().toSet();
    return [
      for (final base in bases) ...[
        base,
        '$base/snap.discord',
        '$base/app/com.discordapp.Discord',
      ],
    ];
  }

  void _onDisconnected() {
    debugPrint('DiscordPresenceService: disconnected from Discord.');
    _socket = null;
    _ready = false;
    _reconnectTimer ??= Timer.periodic(const Duration(seconds: 20), (_) => _connect());
  }

  // ── IPC framing ────────────────────────────────────────────────────────
  // Every message is a 4-byte little-endian opcode, a 4-byte little-endian
  // payload length, then the UTF-8 JSON payload. Opcode 0 = handshake,
  // 1 = a regular command/event frame.

  void _sendHandshake() {
    _send(0, {'v': 1, 'client_id': clientId});
  }

  void _send(int opcode, Map<String, Object?> payload) {
    final socket = _socket;
    if (socket == null) return;
    try {
      final body = utf8.encode(jsonEncode(payload));
      final header = ByteData(8)
        ..setInt32(0, opcode, Endian.little)
        ..setInt32(4, body.length, Endian.little);
      socket.add(header.buffer.asUint8List());
      socket.add(body);
    } catch (e) {
      // e.g. a broken pipe if Discord quit between the last successful read
      // and this write -- _onDisconnected (from the socket's own onError/
      // onDone) handles reconnection; this just stops it from becoming an
      // uncaught exception inside a ChangeNotifier listener callback.
      debugPrint('DiscordPresenceService: send failed: $e');
    }
  }

  void _onData(Uint8List chunk) {
    _incoming.add(chunk);
    var bytes = _incoming.toBytes();
    while (bytes.length >= 8) {
      final view = ByteData.sublistView(bytes);
      final length = view.getInt32(4, Endian.little);
      if (bytes.length < 8 + length) break; // wait for the rest of this frame
      final payload = utf8.decode(bytes.sublist(8, 8 + length));
      _handleMessage(payload);
      bytes = bytes.sublist(8 + length);
    }
    _incoming.clear();
    _incoming.add(bytes);
  }

  void _handleMessage(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, Object?>;
      if (json['evt'] == 'READY') {
        debugPrint('DiscordPresenceService: READY, client_id accepted.');
        _ready = true;
        // A track may already have started playing before Discord finished
        // connecting -- push the current state now instead of waiting for
        // the next play/pause/track-change event.
        _pushActivity(force: true);
      } else if (json['evt'] == 'ERROR') {
        // e.g. {"code":4000,"message":"Invalid Client ID"} -- most likely
        // cause: kDiscordClientId in config.dart isn't a real application id.
        debugPrint('DiscordPresenceService: Discord returned an error: ${json['data']}');
      } else {
        debugPrint('DiscordPresenceService: received $json');
      }
    } catch (e) {
      debugPrint('DiscordPresenceService: bad frame: $e');
    }
  }

  // ── Presence ───────────────────────────────────────────────────────────

  void _setActivity(Track? track, bool isPlaying, Duration position) {
    if (!_ready) return; // _onPlayerChanged runs again once READY arrives

    // Per-track cover art was tried and dropped: Discord doesn't load an
    // external image URL directly, it fetches it server-side through its
    // own media proxy to cache it -- confirmed live that this returns a
    // 502 for our homelab's Tailscale-private address, since Discord's
    // servers (unlike this app's own devices) aren't on that network. A
    // fixed art asset uploaded to the Discord application instead (Rich
    // Presence -> Art Assets in the dev portal) needs no public exposure.
    final activity = track == null
        ? null
        : {
            // type 2 = LISTENING -- renders as "Listening to Nyx" instead of
            // the type-0 default "Playing Nyx", and switches the small
            // controller glyph Discord shows elsewhere (friends list, etc.)
            // to a music-note one. Confirmed live against a real Discord
            // client that a non-partnered app is actually allowed to set
            // this (it's echoed back as sent, not silently coerced to 0).
            'type': 2,
            'name': 'Nyx',
            'details': track.title,
            'state': track.artist,
            if (isPlaying)
              'timestamps': {
                'start': DateTime.now().subtract(position).millisecondsSinceEpoch,
              },
            'assets': {
              'large_image': kDiscordLargeImageKey,
              'large_text': 'Nyx',
            },
            'instance': false,
          };

    debugPrint(
      track == null
          ? 'DiscordPresenceService: clearing activity'
          : 'DiscordPresenceService: setting activity -- ${track.title} / ${track.artist}',
    );
    _send(1, {
      'cmd': 'SET_ACTIVITY',
      'args': {'pid': pid, 'activity': activity},
      'nonce': (_nonce++).toString(),
    });
  }
}
