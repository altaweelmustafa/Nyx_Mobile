import 'package:dio/dio.dart';
import '../repositories/artist_repository.dart';
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
  final _artistRepo = ArtistRepository();

  Future<SyncResult> syncFromServer(String baseUrl) async {
    final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final response = await _dio.get<Map<String, dynamic>>('$url/api/catalog');
    final tracks = ((response.data?['tracks'] as List?) ?? []).cast<Map<String, dynamic>>();

    final catalogSlugs = <String>{};
    final entries = tracks.map((entry) {
      final slug = entry['slug'] as String;
      final audioPath = entry['audio_path'] as String;
      final thumbnailPath = entry['thumbnail_path'] as String?;
      final lyricsPath = entry['lyrics_path'] as String?;
      catalogSlugs.add(slug);
      return CatalogTrackInput(
        slug: slug,
        title: entry['title'] as String,
        artist: entry['artist'] as String,
        audioUrl: '$url/assets/$audioPath',
        thumbnailPath: thumbnailPath != null ? '$url/assets/$thumbnailPath' : null,
        lyricsPath: lyricsPath != null ? '$url/assets/$lyricsPath' : null,
      );
    }).toList();

    // Single batched pass: one read of everything already synced, one
    // transaction for the writes, and any track whose fields already match
    // is skipped entirely -- only genuinely new/changed tracks get written.
    final stats = await _trackRepo.upsertManyFromCatalog(entries);

    final removed = await _trackRepo.deleteMissingFromCatalog(catalogSlugs);

    await _syncArtists(url);

    // One notification for the whole sync, not per track.
    if (stats.added > 0 || stats.updated > 0 || removed > 0) {
      LibraryService.instance.notifyChanged();
    }

    return SyncResult(total: tracks.length, added: stats.added, updated: stats.updated, removed: removed);
  }

  /// Pulls orc's artist photo/bio registry (GET /api/artists) and mirrors
  /// it into the local `artists` table. Best-effort: orc's artist backfill
  /// is a separate, occasionally-run step on that side, so this endpoint
  /// may be briefly ahead of or behind the track catalog -- a failure here
  /// shouldn't fail the whole sync since tracks already synced fine.
  Future<void> _syncArtists(String url) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$url/api/artists');
      final entries = ((response.data?['artists'] as List?) ?? []).cast<Map<String, dynamic>>();
      for (final entry in entries) {
        final name = entry['artist'] as String?;
        if (name == null) continue;
        final photoPath = entry['photo_path'] as String?;
        await _artistRepo.upsert(
          name: name,
          photoPath: photoPath != null ? '$url/assets/$photoPath' : null,
          bio: entry['bio'] as String?,
        );
      }
    } catch (_) {
      // Non-fatal -- the track sync this call already did still counts.
    }
  }
}
