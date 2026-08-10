import 'package:dio/dio.dart';
import '../repositories/track_repository.dart';
import 'library_service.dart';

class SyncResult {
  final int total;
  final int added;
  final int updated;
  final int removed;

  const SyncResult({
    required this.total,
    required this.added,
    required this.updated,
    required this.removed,
  });
}

/// Pulls the track catalog orc has built up on the homelab server
/// (GET /api/catalog) and mirrors it into the local library, keyed by slug:
/// upserts everything present (never resets liked/play_count on update),
/// and removes local synced tracks whose slug is no longer in the catalog
/// (e.g. a track deleted from orc) so deletions on the server propagate too.
class CatalogSyncService {
  final _dio = Dio();
  final _trackRepo = TrackRepository();

  Future<SyncResult> syncFromServer(String baseUrl) async {
    final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final response = await _dio.get<Map<String, dynamic>>('$url/api/catalog');
    final tracks = ((response.data?['tracks'] as List?) ?? []).cast<Map<String, dynamic>>();

    var added = 0;
    var updated = 0;
    final catalogSlugs = <String>{};
    for (final entry in tracks) {
      final slug = entry['slug'] as String;
      final audioPath = entry['audio_path'] as String;
      final thumbnailPath = entry['thumbnail_path'] as String?;
      final lyricsPath = entry['lyrics_path'] as String?;
      catalogSlugs.add(slug);

      final isNew = await _trackRepo.upsertFromCatalog(
        slug: slug,
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

    final removed = await _trackRepo.deleteMissingFromCatalog(catalogSlugs);

    // One notification for the whole sync, not per track -- see
    // upsertFromCatalog's doc comment for why it doesn't notify itself.
    if (added > 0 || updated > 0 || removed > 0) {
      LibraryService.instance.notifyChanged();
    }

    return SyncResult(total: tracks.length, added: added, updated: updated, removed: removed);
  }
}
