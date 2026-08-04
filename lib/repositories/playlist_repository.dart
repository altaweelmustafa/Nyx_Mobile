import '../db/app_database.dart';
import '../models/playlist.dart';
import '../models/track.dart';

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

  Future<void> setLiked(String playlistId, bool liked) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'playlists',
      {'liked': liked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [int.parse(playlistId)],
    );
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
    return id.toString();
  }

  Future<void> rename(String playlistId, String name) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'playlists',
      {'name': name},
      where: 'id = ?',
      whereArgs: [int.parse(playlistId)],
    );
  }

  Future<void> delete(String playlistId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [int.parse(playlistId)]);
  }

  Future<void> addTrack(String playlistId, String trackId) async {
    final db = await AppDatabase.instance.database;
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
  }
}
