import 'dart:async';

import 'package:app_links/app_links.dart';

import '../models/track.dart';
import '../repositories/track_repository.dart';

/// Resolves incoming `http://<homelab>:8086/t/<slug>` links (see the
/// browsable intent-filter in AndroidManifest.xml) into a [Track] the UI can
/// navigate to. One instance lives for the app's lifetime.
///
/// Cold-start links (app launched by tapping the link) come through
/// [takeInitialTrack], consumed once by StartScreen after the tailnet gate
/// clears. Links tapped while the app is already running arrive on
/// [trackStream] and are handled wherever the app currently is (see
/// BragerApp's listener in main.dart).
class DeepLinkService {
  DeepLinkService._() {
    _appLinks.uriLinkStream.listen((uri) async {
      final track = await _resolve(uri);
      if (track != null) _controller.add(track);
    });
  }

  static final instance = DeepLinkService._();

  final _appLinks = AppLinks();
  final _controller = StreamController<Track>.broadcast();
  final _trackRepo = TrackRepository();

  Stream<Track> get trackStream => _controller.stream;

  Future<Track?> takeInitialTrack() async {
    final uri = await _appLinks.getInitialLink();
    if (uri == null) return null;
    return _resolve(uri);
  }

  Future<Track?> _resolve(Uri uri) async {
    final segments = uri.pathSegments;
    if (segments.length != 2 || segments[0] != 't') return null;
    return _trackRepo.getBySlug(segments[1]);
  }
}
