import 'package:dio/dio.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/track_repository.dart';

class PlaylistSyncResult {
  final int uploaded;
  final int pulled;
  final int removed;

  const PlaylistSyncResult({
    required this.uploaded,
    required this.pulled,
    required this.removed,
  });
}

/// Mirrors playlists against orc's /api/playlists so a playlist created on
/// one device is visible -- and editable -- from every device that syncs
/// against the same server, the same trust model as the rest of
/// orc/brager (Tailscale's network boundary, not per-user auth).
///
/// A playlist is identified across devices by its server-assigned id
/// (Playlist.serverId / playlists.server_id locally) and its track
/// membership by track *slug* -- the one identifier that already means the
/// same thing on every device (see TrackRepository/CatalogSyncService).
/// Locally-added tracks (slug IS NULL) can't be part of a shared playlist;
/// adding one to a linked playlist succeeds locally but isn't pushed.
/// Locked artist-snapshot playlists (source_artist != null) never sync --
/// they're deliberately frozen local snapshots.
///
/// The push* methods are called by PlaylistRepository's callers right
/// after each local mutation so edits usually propagate immediately; they
/// swallow network failures so an offline edit still applies locally and
/// gets reconciled by the next syncFromServer. syncFromServer itself is
/// the full two-way pass run from the existing "Sync Now" screen: upload
/// anything not yet linked, then pull and mirror everything the server has.
class PlaylistSyncService {
  static final instance = PlaylistSyncService._();
  PlaylistSyncService._();

  final _dio = Dio();
  final _playlistRepo = PlaylistRepository();
  final _trackRepo = TrackRepository();
  final _profileRepo = ProfileRepository();

  Future<String> _baseUrl() async {
    final url = await _profileRepo.getServerUrl();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<void> pushCreate(Playlist playlist, List<Track> tracks) async {
    if (playlist.isLocked || playlist.isShared) return;
    final slugs = [for (final t in tracks) if (t.slug != null) t.slug!];
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${await _baseUrl()}/api/playlists',
        data: {'name': playlist.name, 'track_slugs': slugs},
      );
      final serverId = response.data?['result']?['id'] as String?;
      if (serverId != null) {
        await _playlistRepo.linkToServer(playlist.id, serverId);
      }
    } catch (_) {
      // Offline/unreachable -- stays unlinked, picked up by the next
      // syncFromServer's upload pass.
    }
  }

  Future<void> pushAddTrack(Playlist playlist, Track track) async {
    if (!playlist.isShared || track.slug == null) return;
    try {
      await _dio.post(
        '${await _baseUrl()}/api/playlists/${playlist.serverId}/tracks',
        data: {'slug': track.slug},
      );
    } catch (_) {}
  }

  Future<void> pushRemoveTrack(Playlist playlist, Track track) async {
    if (!playlist.isShared || track.slug == null) return;
    try {
      await _dio.delete(
        '${await _baseUrl()}/api/playlists/${playlist.serverId}/tracks/${track.slug}',
      );
    } catch (_) {}
  }

  Future<void> pushRename(Playlist playlist, String newName) async {
    if (!playlist.isShared) return;
    try {
      await _dio.patch(
        '${await _baseUrl()}/api/playlists/${playlist.serverId}',
        data: {'name': newName},
      );
    } catch (_) {}
  }

  Future<void> pushDelete(Playlist playlist) async {
    if (!playlist.isShared) return;
    try {
      await _dio.delete('${await _baseUrl()}/api/playlists/${playlist.serverId}');
    } catch (_) {}
  }

  Future<PlaylistSyncResult> syncFromServer(String baseUrl) async {
    final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    var uploaded = 0;
    for (final playlist in await _playlistRepo.getUnlinkedShareable()) {
      final tracks = await _playlistRepo.getTracks(playlist.id);
      final slugs = [for (final t in tracks) if (t.slug != null) t.slug!];
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$url/api/playlists',
          data: {'name': playlist.name, 'track_slugs': slugs},
        );
        final serverId = response.data?['result']?['id'] as String?;
        if (serverId != null) {
          await _playlistRepo.linkToServer(playlist.id, serverId);
          uploaded++;
        }
      } catch (_) {
        // Leave unlinked -- retried on the next Sync Now.
      }
    }

    final response = await _dio.get<Map<String, dynamic>>('$url/api/playlists');
    final serverPlaylists = ((response.data?['playlists'] as List?) ?? [])
        .cast<Map<String, dynamic>>();

    var pulled = 0;
    final serverIds = <String>{};
    for (final entry in serverPlaylists) {
      final serverId = entry['id'] as String;
      final name = entry['name'] as String;
      final slugs = ((entry['track_slugs'] as List?) ?? []).cast<String>();
      serverIds.add(serverId);

      var local = await _playlistRepo.getByServerId(serverId);
      local ??= await _playlistRepo.createLinked(name: name, serverId: serverId);
      if (local.name != name) {
        await _playlistRepo.updateName(local.id, name);
      }

      final localTrackIds = <String>[];
      for (final slug in slugs) {
        final track = await _trackRepo.getBySlug(slug);
        if (track != null) localTrackIds.add(track.id);
      }
      await _playlistRepo.replaceTrackMembership(local.id, localTrackIds);
      pulled++;
    }

    final removed = await _playlistRepo.deleteMissingFromServer(serverIds);

    return PlaylistSyncResult(uploaded: uploaded, pulled: pulled, removed: removed);
  }
}
