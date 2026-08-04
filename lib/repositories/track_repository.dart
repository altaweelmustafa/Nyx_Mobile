import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/track.dart';

class TrackRepository {
  Future<List<Track>> _query(String where, [List<Object?>? args]) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('tracks', where: where, whereArgs: args, orderBy: 'id');
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

  /// Tracks you haven't played yet, by artists you've recently been
  /// listening to. Simple "you might also like" -- not a real recommender.
  Future<List<Track>> getRecommended(int limit) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT * FROM tracks
      WHERE song != 'RADIO'
        AND last_played_at IS NULL
        AND artist IN (
          SELECT DISTINCT artist FROM tracks
          WHERE last_played_at IS NOT NULL
          ORDER BY last_played_at DESC
          LIMIT 5
        )
      ORDER BY liked DESC, id
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(Track.fromMap).toList();
  }

  Future<int> countLiked() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM tracks WHERE liked = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Track?> getById(String id) async {
    final rows = await _query('id = ?', [int.parse(id)]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteTrack(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('tracks', where: 'id = ?', whereArgs: [int.parse(id)]);
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
  }

  Future<void> incrementPlayCount(String id) async {
    final trackId = int.tryParse(id);
    if (trackId == null) return; // e.g. the synthetic Jam-follower track
    final db = await AppDatabase.instance.database;
    await db.rawUpdate(
      'UPDATE tracks SET play_count = play_count + 1, last_played_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, trackId],
    );
  }

  /// Inserts or updates a track by its server catalog slug. Only the
  /// synced fields (title/artist/audio_url/thumbnail_path/lyrics_path) get
  /// overwritten -- liked/play_count/liked_at are left alone so re-syncing
  /// never resets local state. Returns true if this was a new track.
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
    final existing = await db.query('tracks', where: 'slug = ?', whereArgs: [slug], limit: 1);

    if (existing.isEmpty) {
      await db.insert('tracks', {
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
      return true;
    }

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
    return false;
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
    return id.toString();
  }
}
