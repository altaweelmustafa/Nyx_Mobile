import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/track.dart';
import '../services/library_service.dart';
import '../utils/artist_names.dart';

class TrackRepository {
  Future<List<Track>> _query(String where, [List<Object?>? args]) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'tracks',
      where: where,
      whereArgs: args,
      orderBy: 'id',
    );
    return rows.map(Track.fromMap).toList();
  }

  Future<List<Track>> getAll() => _query('1 = 1');

  /// Radio gets its own row on Home and plays as a single station, not a
  /// skippable queue.
  Future<List<Track>> getRadioStations() => _query("song = 'RADIO'");

  /// Most recently liked first -- matches how a "saved" list should read.
  Future<List<Track>> getLiked() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'tracks',
      where: 'liked = 1',
      orderBy: 'liked_at DESC, id DESC',
    );
    return rows.map(Track.fromMap).toList();
  }

  Future<List<Track>> getMostPlayed(int limit) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'tracks',
      where: "song != 'RADIO' AND play_count > 0",
      orderBy: 'play_count DESC, last_played_at DESC',
      limit: limit,
    );
    return rows.map(Track.fromMap).toList();
  }

  /// Most recently added tracks -- "new releases" in the absence of a real
  /// release-date field.
  Future<List<Track>> getNewReleases(int limit) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'tracks',
      where: "song != 'RADIO'",
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(Track.fromMap).toList();
  }

  /// All tracks credited to [artist], for "play this artist" from an artist
  /// card. Matches via track_artists (individual split names), so a track
  /// credited to "Grimes & Lizzy Wizzy" shows up under both artists, not
  /// just an exact match on the raw joined string.
  Future<List<Track>> getByArtist(String artist) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT t.* FROM tracks t
      JOIN track_artists ta ON ta.track_id = t.id
      WHERE t.song != 'RADIO' AND ta.artist_name = ?
      ORDER BY t.id
      ''',
      [artist],
    );
    return rows.map(Track.fromMap).toList();
  }

  /// Escapes SQLite LIKE metacharacters (and the escape char itself) so a
  /// literal '%' or '_' typed into search is matched literally, not as a
  /// wildcard.
  String _escapeLikePattern(String raw) =>
      raw.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_');

  /// Title/artist search for the Search screen -- case-insensitive, capped
  /// at [limit] so a broad query doesn't dump the whole library. Matches
  /// artist via track_artists (individual names), not the raw column.
  Future<List<Track>> searchTracks(String query, {int limit = 10}) async {
    final db = await AppDatabase.instance.database;
    final pattern = '%${_escapeLikePattern(query.toLowerCase())}%';
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT t.* FROM tracks t
      LEFT JOIN track_artists ta ON ta.track_id = t.id
      WHERE t.song != 'RADIO'
        AND (LOWER(t.title) LIKE ? ESCAPE '!' OR LOWER(ta.artist_name) LIKE ? ESCAPE '!')
      ORDER BY t.id
      LIMIT ?
      ''',
      [pattern, pattern, limit],
    );
    return rows.map(Track.fromMap).toList();
  }

  /// Distinct artist names matching [query], capped at [limit], each paired
  /// with a thumbnail -- their real synced cover (artists.photo_path) when
  /// orc has one cached, else a stand-in from one of their track
  /// thumbnails. Backs the Search screen's artist row.
  Future<List<({String name, String? thumbnailPath})>> searchArtists(
    String query, {
    int limit = 10,
  }) async {
    final db = await AppDatabase.instance.database;
    final pattern = '%${_escapeLikePattern(query.toLowerCase())}%';
    final rows = await db.rawQuery(
      '''
      SELECT ta.artist_name AS artist,
             COALESCE(MIN(a.photo_path), MIN(t.thumbnail_path)) AS thumbnail_path
      FROM track_artists ta
      JOIN tracks t ON t.id = ta.track_id
      LEFT JOIN artists a ON a.name = ta.artist_name
      WHERE t.song != 'RADIO' AND LOWER(ta.artist_name) LIKE ? ESCAPE '!'
      GROUP BY ta.artist_name
      ORDER BY ta.artist_name
      LIMIT ?
      ''',
      [pattern, limit],
    );
    return rows
        .map(
          (r) => (
            name: r['artist'] as String,
            thumbnailPath: r['thumbnail_path'] as String?,
          ),
        )
        .toList();
  }

  /// Newly-added tracks for Home's "Recommended" row, deduped to one
  /// representative track per (split) artist -- uploading several songs by
  /// the same artist at once shows that artist once, not every track; the
  /// rest are one tap away on the artist's own page. [poolLimit] bounds how
  /// far back into newest-first order to look while collecting [limit]
  /// distinct-artist representatives.
  Future<List<Track>> getRecentlyAddedMix(int limit, {int poolLimit = 60}) async {
    final pool = await getNewReleases(poolLimit);
    final seenArtists = <String>{};
    final result = <Track>[];
    for (final track in pool) {
      final names = splitArtists(track.artist);
      if (names.any((n) => !seenArtists.contains(n))) {
        result.add(track);
        seenArtists.addAll(names);
        if (result.length == limit) break;
      }
    }
    return result;
  }

  /// Random tracks not already in [excludeIds] -- used to keep the queue
  /// going once a non-personal listening context (Recommended, an artist,
  /// a search result, ...) runs out of tracks, instead of stopping playback.
  Future<List<Track>> getAutoplaySuggestions(
    Set<String> excludeIds,
    int limit,
  ) async {
    final db = await AppDatabase.instance.database;
    final ids = excludeIds.map(int.tryParse).whereType<int>().toList();
    final exclusion = ids.isEmpty
        ? ''
        : 'AND id NOT IN (${List.filled(ids.length, '?').join(',')})';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM tracks
      WHERE song != 'RADIO' $exclusion
      ORDER BY RANDOM()
      LIMIT ?
      ''',
      [...ids, limit],
    );
    return rows.map(Track.fromMap).toList();
  }

  Future<int> countLiked() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tracks WHERE liked = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Track?> getById(String id) async {
    final rows = await _query('id = ?', [int.parse(id)]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteTrack(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('tracks', where: 'id = ?', whereArgs: [int.parse(id)]);
    LibraryService.instance.notifyChanged();
  }

  Future<void> setLiked(String id, bool liked) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'tracks',
      {
        'liked': liked ? 1 : 0,
        if (liked) 'liked_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
    LibraryService.instance.notifyChanged();
  }

  Future<void> incrementPlayCount(String id) async {
    final trackId = int.tryParse(id);
    if (trackId == null) return; // e.g. the synthetic Jam-follower track
    final db = await AppDatabase.instance.database;
    await db.rawUpdate(
      'UPDATE tracks SET play_count = play_count + 1, last_played_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, trackId],
    );
    LibraryService.instance.notifyChanged();
  }

  /// Inserts or updates a track by its server catalog slug. Only the
  /// synced fields (title/artist/audio_url/thumbnail_path/lyrics_path) get
  /// overwritten -- liked/play_count/liked_at are left alone so re-syncing
  /// never resets local state. Returns true if this was a new track.
  ///
  /// Deliberately does NOT call LibraryService.notifyChanged() itself --
  /// CatalogSyncService calls this once per track in a loop, and firing a
  /// notification per track would spam every listening screen with a
  /// reload mid-sync. CatalogSyncService notifies once after the whole
  /// sync (upserts + deleteMissingFromCatalog) finishes instead.
  Future<bool> upsertFromCatalog({
    required String slug,
    required String title,
    required String artist,
    required String audioUrl,
    String? thumbnailPath,
    String? lyricsPath,
    String song = 'SONG',
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query(
      'tracks',
      where: 'slug = ?',
      whereArgs: [slug],
      limit: 1,
    );

    if (existing.isEmpty) {
      final id = await db.insert('tracks', {
        'title': title,
        'artist': artist,
        'song': song,
        'audio_url': audioUrl,
        'thumbnail_path': thumbnailPath,
        'lyrics_path': lyricsPath,
        'slug': slug,
        'liked': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _syncTrackArtists(db, id, artist);
      return true;
    }

    final id = existing.first['id'] as int;
    await db.update(
      'tracks',
      {
        'title': title,
        'artist': artist,
        'audio_url': audioUrl,
        'thumbnail_path': thumbnailPath,
        'lyrics_path': lyricsPath,
      },
      where: 'slug = ?',
      whereArgs: [slug],
    );
    await _syncTrackArtists(db, id, artist);
    return false;
  }

  /// Replaces track_artists for [trackId] with a fresh split of [artist] --
  /// called on every write to `tracks` that can change its artist column,
  /// so "which artist pages include this track" always matches the current
  /// credit. Delete-then-reinsert rather than diffing, since this table is
  /// tiny per track.
  Future<void> _syncTrackArtists(Database db, int trackId, String artist) async {
    await db.delete('track_artists', where: 'track_id = ?', whereArgs: [trackId]);
    for (final name in splitArtists(artist)) {
      await db.insert(
        'track_artists',
        {'track_id': trackId, 'artist_name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Deletes synced tracks (slug IS NOT NULL) whose slug is no longer in
  /// [catalogSlugs] -- mirrors server-side removals (e.g. a track deleted
  /// from orc's catalog) into the local library on the next sync. Locally
  /// added tracks (slug IS NULL) are never touched. Refuses to run against
  /// an empty [catalogSlugs] so a failed/empty fetch can't wipe the library.
  /// Cascades to playlist_tracks via the existing ON DELETE CASCADE.
  Future<int> deleteMissingFromCatalog(Set<String> catalogSlugs) async {
    if (catalogSlugs.isEmpty) return 0;
    final db = await AppDatabase.instance.database;
    final placeholders = List.filled(catalogSlugs.length, '?').join(',');
    return db.delete(
      'tracks',
      where: 'slug IS NOT NULL AND slug NOT IN ($placeholders)',
      whereArgs: catalogSlugs.toList(),
    );
  }

  /// Inserts a freshly-imported track and returns its new id.
  Future<String> insertTrack({
    required String title,
    required String artist,
    required String audioUrl,
    String song = 'SONG',
    String? thumbnailPath,
    String? lyricsPath,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('tracks', {
      'title': title,
      'artist': artist,
      'song': song,
      'audio_url': audioUrl,
      'thumbnail_path': thumbnailPath,
      'lyrics_path': lyricsPath,
      'liked': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _syncTrackArtists(db, id, artist);
    LibraryService.instance.notifyChanged();
    return id.toString();
  }
}
