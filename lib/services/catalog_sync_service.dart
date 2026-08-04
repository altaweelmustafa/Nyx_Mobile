import 'package:dio/dio.dart';
import '../repositories/track_repository.dart';

class SyncResult {
  final int total;
  final int added;
  final int updated;

  const SyncResult({required this.total, required this.added, required this.updated});
}

/// Pulls the track catalog orc has built up on the homelab server
/// (GET /api/catalog) and upserts it into the local library, keyed by slug
/// so re-syncing never creates duplicates.
class CatalogSyncService {
  final _dio = Dio();
  final _trackRepo = TrackRepository();

  Future<SyncResult> syncFromServer(String baseUrl) async {
    final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final response = await _dio.get<Map<String, dynamic>>('$url/api/catalog');
    final tracks = ((response.data?['tracks'] as List?) ?? []).cast<Map<String, dynamic>>();

    var added = 0;
    var updated = 0;
    for (final entry in tracks) {
      final audioPath = entry['audio_path'] as String;
      final thumbnailPath = entry['thumbnail_path'] as String?;
      final lyricsPath = entry['lyrics_path'] as String?;

      final isNew = await _trackRepo.upsertFromCatalog(
        slug: entry['slug'] as String,
        title: entry['title'] as String,
        artist: entry['artist'] as String,
        audioUrl: '$url/assets/$audioPath',
        thumbnailPath: thumbnailPath != null ? '$url/assets/$thumbnailPath' : null,
        lyricsPath: lyricsPath != null ? '$url/assets/$lyricsPath' : null,
      );
      if (isNew) {
        added++;
      } else {
        updated++;
      }
    }

    return SyncResult(total: tracks.length, added: added, updated: updated);
  }
}
