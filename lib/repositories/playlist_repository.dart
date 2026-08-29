import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/library_service.dart';

class PlaylistRepository {
  Future<List<Playlist>> _query(String where) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT p.*, COUNT(pt.track_id) AS track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
      WHERE $where
      GROUP BY p.id
      ORDER BY p.id
    ''');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<List<Playlist>> getAll() => _query('1 = 1');

  /// Playlists you've saved/liked -- this is what shows up in Your Library.
  Future<List<Playlist>> getLiked() => _query('p.liked = 1');

  /// The playlist previously saved from this artist's page via "Save as
  /// Playlist", if any.
  Future<Playlist?> getBySourceArtist(String artistName) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT p.*, COUNT(pt.track_id) AS track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
      WHERE p.source_artist = ?
      GROUP BY p.id
      ''',
      [artistName],
    );
    return rows.isEmpty ? null : Playlist.fromMap(rows.first);
  }

  /// Creates a locked snapshot playlist named after [artistName], containing
  /// exactly [trackIds] in order -- used by ArtistScreen's "Save as
  /// Playlist". The snapshot doesn't stay in sync with the artist's catalog
  /// afterward; that's what "locked" means here.
  Future<Playlist> createFromArtist(
    String artistName,
    List<String> trackIds,
  ) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('playlists', {
      'name': artistName,
      'source_artist': artistName,
      'likes': 0,
      'liked': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    for (var i = 0; i < trackIds.length; i++) {
      await db.insert('playlist_tracks', {
        'playlist_id': id,
        'track_id': int.parse(trackIds[i]),
        'position': i,
      });
    }
    LibraryService.instance.notifyChanged();
    return (await getBySourceArtist(artistName))!;
  }

  Future<void> setLiked(String playlistId, bool liked) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'playlists',
      {'liked': liked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [int.parse(playlistId)],
    );
    LibraryService.instance.notifyChanged();
  }

  Future<List<Track>> getTracks(String playlistId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT t.*
      FROM tracks t
      JOIN playlist_tracks pt ON pt.track_id = t.id
      WHERE pt.playlist_id = ?
      ORDER BY pt.position
      ''',
      [int.parse(playlistId)],
    );
    return rows.map(Track.fromMap).toList();
  }

  /// Thumbnails of the first [limit] tracks in the playlist, in order --
  /// backs the "deck of cards" stacked cover used on Home suggestions and
  /// in Search results. May contain nulls (tracks with no thumbnail) and
  /// can be shorter than [limit] for small playlists.
  Future<List<String?>> getTrackThumbnails(
    String playlistId, {
    int limit = 4,
  }) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT t.thumbnail_path
      FROM tracks t
      JOIN playlist_tracks pt ON pt.track_id = t.id
      WHERE pt.playlist_id = ?
      ORDER BY pt.position
      LIMIT ?
      ''',
      [int.parse(playlistId), limit],
    );
    return rows.map((r) => r['thumbnail_path'] as String?).toList();
  }

  /// Escapes SQLite LIKE metacharacters so a literal '%' or '_' typed into
  /// search is matched literally, not as a wildcard.
  String _escapeLikePattern(String raw) =>
      raw.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_');

  /// Name search for the Search screen -- every playlist is discoverable
  /// this way (not just ones currently saved/liked into Your Library),
  /// which is what makes playlists "public" within the app.
  Future<List<Playlist>> searchPlaylists(String query, {int limit = 10}) async {
    final db = await AppDatabase.instance.database;
    final pattern = '%${_escapeLikePattern(query.toLowerCase())}%';
    final rows = await db.rawQuery(
      '''
      SELECT p.*, COUNT(pt.track_id) AS track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
      WHERE LOWER(p.name) LIKE ? ESCAPE '!'
      GROUP BY p.id
      ORDER BY p.name
      LIMIT ?
      ''',
      [pattern, limit],
    );
    return rows.map(Playlist.fromMap).toList();
  }

  Future<String> create(String name) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('playlists', {
      'name': name,
      'likes': 0,
      'liked': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    LibraryService.instance.notifyChanged();
    return id.toString();
  }

  /// Rename/addTrack/removeTrack all no-op on a locked (source_artist != null)
  /// playlist -- callers are expected to keep that UI hidden, but this is the
  /// backstop that actually makes "cannot be modified" true regardless of
  /// which screen a call comes from.
  Future<bool> _isLocked(Database db, String playlistId) async {
    final rows = await db.query(
      'playlists',
      columns: ['source_artist'],
      where: 'id = ?',
      whereArgs: [int.parse(playlistId)],
    );
    return rows.isNotEmpty && rows.first['source_artist'] != null;
  }

  Future<void> rename(String playlistId, String name) async {
    final db = await AppDatabase.instance.database;
    if (await _isLocked(db, playlistId)) return;
    await db.update(
      'playlists',
      {'name': name},
      where: 'id = ?',
      whereArgs: [int.parse(playlistId)],
    );
    LibraryService.instance.notifyChanged();
  }

  Future<void> delete(String playlistId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [int.parse(playlistId)]);
    LibraryService.instance.notifyChanged();
  }

  Future<void> addTrack(String playlistId, String trackId) async {
    final db = await AppDatabase.instance.database;
    if (await _isLocked(db, playlistId)) return;
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS maxPos FROM playlist_tracks WHERE playlist_id = ?',
      [int.parse(playlistId)],
    );
    final nextPosition = (result.first['maxPos'] as int) + 1;
    await db.insert('playlist_tracks', {
      'playlist_id': int.parse(playlistId),
      'track_id': int.parse(trackId),
      'position': nextPosition,
    });
    LibraryService.instance.notifyChanged();
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    final db = await AppDatabase.instance.database;
    if (await _isLocked(db, playlistId)) return;
    await db.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [int.parse(playlistId), int.parse(trackId)],
    );
    LibraryService.instance.notifyChanged();
  }

  // ── Server sync (PlaylistSyncService) ──────────────────────────────────
  // Everything below is local-DB plumbing for mirroring playlists against
  // orc's /api/playlists -- PlaylistSyncService owns the actual HTTP calls
  // and slug<->local-track-id translation; these methods just give it the
  // local reads/writes it needs.

  Future<Playlist?> getByServerId(String serverId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT p.*, COUNT(pt.track_id) AS track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
      WHERE p.server_id = ?
      GROUP BY p.id
      ''',
      [serverId],
    );
    return rows.isEmpty ? null : Playlist.fromMap(rows.first);
  }

  /// Non-locked, not-yet-uploaded local playlists -- candidates for the
  /// one-time upload step that registers pre-existing local playlists on
  /// the server the first time this device syncs after the feature ships.
  Future<List<Playlist>> getUnlinkedShareable() =>
      _query('p.source_artist IS NULL AND p.server_id IS NULL');

  Future<void> linkToServer(String playlistId, String serverId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'playlists',
      {'server_id': serverId},
      where: 'id = ?',
      whereArgs: [int.parse(playlistId)],
    );
  }

  /// Mirrors a playlist this device has never seen before, pulled from the
  /// server -- starts un-liked (not automatically added to Your Library);
  /// the user has to explicitly "add" it, same as any other shared
  /// playlist surfaced through suggestions or search.
  Future<Playlist> createLinked({required String name, required String serverId}) async {
    final db = await AppDatabase.instance.database;
    await db.insert('playlists', {
      'name': name,
      'server_id': serverId,
      'likes': 0,
      'liked': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return (await getByServerId(serverId))!;
  }

  Future<void> updateName(String playlistId, String name) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'playlists',
      {'name': name},
      where: 'id = ?',
      whereArgs: [int.parse(playlistId)],
    );
    LibraryService.instance.notifyChanged();
  }

  /// Replaces this playlist's entire track list with [localTrackIds], in
  /// order -- how a pull reconciles local membership to match the
  /// server's ordered slug list in one shot, rather than diffing.
  Future<void> replaceTrackMembership(String playlistId, List<String> localTrackIds) async {
    final db = await AppDatabase.instance.database;
    final pid = int.parse(playlistId);
    await db.transaction((txn) async {
      await txn.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [pid]);
      for (var i = 0; i < localTrackIds.length; i++) {
        await txn.insert('playlist_tracks', {
          'playlist_id': pid,
          'track_id': int.parse(localTrackIds[i]),
          'position': i,
        });
      }
    });
    LibraryService.instance.notifyChanged();
  }

  /// Removes local mirrors of shared playlists that no longer exist on the
  /// server (deleted from another device) -- symmetric with
  /// TrackRepository.deleteMissingFromCatalog. Guarded against an
  /// empty/failed fetch wiping everything, and never touches playlists
  /// that were never linked (server_id IS NULL).
  Future<int> deleteMissingFromServer(Set<String> serverIds) async {
    if (serverIds.isEmpty) return 0;
    final db = await AppDatabase.instance.database;
    final placeholders = List.filled(serverIds.length, '?').join(',');
    final removed = await db.delete(
      'playlists',
      where: 'server_id IS NOT NULL AND server_id NOT IN ($placeholders)',
      whereArgs: serverIds.toList(),
    );
    if (removed > 0) LibraryService.instance.notifyChanged();
    return removed;
  }
}
