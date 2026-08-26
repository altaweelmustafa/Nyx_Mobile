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
}
