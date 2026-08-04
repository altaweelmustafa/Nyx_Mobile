import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../config.dart';

/// Owns the single SQLite connection the whole app reads/writes through --
/// tracks, playlists, playlist membership, and search history all live here.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'brager.db';
  static const _version = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, _fileName);

    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    // Schema has grown ad hoc during development without version bumps, so
    // self-heal on every open rather than relying on onUpgrade -- cheap and
    // idempotent, and fixes installs whose on-disk schema predates a column.
    await _ensureSchema(db);
    return db;
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profile (
        id           INTEGER PRIMARY KEY CHECK (id = 1),
        display_name TEXT NOT NULL
      )
    ''');
    final profileRows = await db.query('profile', where: 'id = 1');
    if (profileRows.isEmpty) {
      await db.insert('profile', {'id': 1, 'display_name': 'admin', 'server_url': kDefaultServerUrl});
    }

    final profileColumns = await db.rawQuery("PRAGMA table_info('profile')");
    if (!profileColumns.any((c) => c['name'] == 'avatar_path')) {
      await db.execute('ALTER TABLE profile ADD COLUMN avatar_path TEXT');
    }
    if (!profileColumns.any((c) => c['name'] == 'server_url')) {
      await db.execute('ALTER TABLE profile ADD COLUMN server_url TEXT');
      await db.update('profile', {'server_url': kDefaultServerUrl}, where: 'id = 1');
    }

    final playlistColumns = await db.rawQuery("PRAGMA table_info('playlists')");
    final hasLiked = playlistColumns.any((c) => c['name'] == 'liked');
    if (!hasLiked) {
      await db.execute('ALTER TABLE playlists ADD COLUMN liked INTEGER NOT NULL DEFAULT 1');
    }

    final trackColumns = await db.rawQuery("PRAGMA table_info('tracks')");
    final trackColumnNames = trackColumns.map((c) => c['name']).toSet();
    if (!trackColumnNames.contains('liked_at')) {
      await db.execute('ALTER TABLE tracks ADD COLUMN liked_at INTEGER');
      // Backfill so already-liked tracks don't vanish from a liked_at DESC sort.
      await db.execute(
        'UPDATE tracks SET liked_at = created_at WHERE liked = 1 AND liked_at IS NULL',
      );
    }
    if (!trackColumnNames.contains('play_count')) {
      await db.execute('ALTER TABLE tracks ADD COLUMN play_count INTEGER NOT NULL DEFAULT 0');
    }
    if (!trackColumnNames.contains('last_played_at')) {
      await db.execute('ALTER TABLE tracks ADD COLUMN last_played_at INTEGER');
    }
    if (!trackColumnNames.contains('slug')) {
      await db.execute('ALTER TABLE tracks ADD COLUMN slug TEXT');
      final existingIndex = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_tracks_slug'",
      );
      if (existingIndex.isEmpty) {
        await db.execute(
          'CREATE UNIQUE INDEX idx_tracks_slug ON tracks(slug) WHERE slug IS NOT NULL',
        );
      }
    }

    await _migrateLegacyBundledTracks(db);
    await _ensureDefaultRadioStations(db);
  }

  /// The 6 tracks that used to ship bundled as Flutter assets now live on
  /// the homelab server instead (moved 2026-08-04). Existing installs still
  /// have rows pointing at the old `asset:///assets/audio/...` paths, which
  /// no longer resolve to anything once those files are gone from the APK --
  /// rewrite them in place (preserving liked/play_count/playlist membership)
  /// and give them a slug so a later server sync recognizes them instead of
  /// inserting duplicates. Guarded by `slug IS NULL` so it only ever touches
  /// a row once.
  Future<void> _migrateLegacyBundledTracks(Database db) async {
    const legacyTracks = [
      {'oldAudio': 'asset:///assets/audio/summertime_sadness.mp3', 'slug': 'summertime_sadness', 'audio': 'audio/summertime_sadness.mp3', 'thumb': 'images/summertime_sadness.jpg', 'lyrics': 'lyrics/summertime_sadness.lrc'},
      {'oldAudio': 'asset:///assets/audio/on_my_way.mp3', 'slug': 'on_my_way', 'audio': 'audio/on_my_way.mp3', 'thumb': 'images/on_my_way.jpg', 'lyrics': 'lyrics/on_my_way.lrc'},
      {'oldAudio': 'asset:///assets/audio/faded.mp3', 'slug': 'faded', 'audio': 'audio/faded.mp3', 'thumb': 'images/faded.jpg', 'lyrics': 'lyrics/faded.lrc'},
      {'oldAudio': 'asset:///assets/audio/grimes_genesis.m4a', 'slug': 'grimes_genesis', 'audio': 'audio/grimes_genesis.m4a', 'thumb': 'images/grimes_genesis.jpg', 'lyrics': 'lyrics/grimes_genesis.lrc'},
      {'oldAudio': 'asset:///assets/audio/grimes_lizzy_wizzy_delicate_weapon.m4a', 'slug': 'grimes_lizzy_wizzy_delicate_weapon', 'audio': 'audio/grimes_lizzy_wizzy_delicate_weapon.m4a', 'thumb': 'images/grimes_lizzy_wizzy_delicate_weapon.jpg', 'lyrics': 'lyrics/grimes_lizzy_wizzy_delicate_weapon.lrc'},
      {'oldAudio': 'asset:///assets/audio/sabrina_carpenter_espresso.m4a', 'slug': 'sabrina_carpenter_espresso', 'audio': 'audio/sabrina_carpenter_espresso.m4a', 'thumb': 'images/sabrina_carpenter_espresso.jpg', 'lyrics': 'lyrics/sabrina_carpenter_espresso.lrc'},
    ];

    for (final t in legacyTracks) {
      await db.update(
        'tracks',
        {
          'audio_url': '$kDefaultServerUrl/assets/${t['audio']}',
          'thumbnail_path': '$kDefaultServerUrl/assets/${t['thumb']}',
          'lyrics_path': '$kDefaultServerUrl/assets/${t['lyrics']}',
          'slug': t['slug'],
        },
        where: 'audio_url = ? AND slug IS NULL',
        whereArgs: [t['oldAudio']],
      );
    }
  }

  /// Real Egyptian FM stations (stream URLs sourced from radio-browser.info,
  /// a public directory) -- self-healed like the schema above so existing
  /// installs pick up new/changed stations too, not just fresh ones.
  /// Matched by audio_url so re-running this is a no-op once inserted.
  Future<void> _ensureDefaultRadioStations(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const stations = [
      {
        'title': 'NRJ Egypt',
        'artist': 'Pop Hits · Cairo',
        'url': 'https://nrjstreaming.ahmed-melege.com/nrjegypt',
      },
      {
        // zeno.fm stream id without its signed session token -- usually still
        // playable directly, but zeno.fm has been known to rotate these; if
        // this one goes dead, look up a fresh id at https://www.nogoumfm.net.
        'title': 'Nogoum FM',
        'artist': '100.6 FM · Cairo',
        'url': 'https://stream-159.zeno.fm/qb1zvsykm98uv',
      },
      {
        'title': '9090 FM',
        'artist': '90.9 FM · Egypt',
        'url': 'http://9090streaming.mobtada.com/9090FMEGYPT',
      },
      {
        'title': 'On Sport FM',
        'artist': 'Sports · Egypt',
        'url': 'https://carina.streamerr.co:2020/stream/OnSportFM',
      },
      {
        'title': 'Sha3by FM',
        'artist': 'Sha3bi Music · Egypt',
        'url': 'https://radio95.radioca.st/',
      },
    ];

    for (final station in stations) {
      final existing = await db.query(
        'tracks',
        where: 'audio_url = ?',
        whereArgs: [station['url']],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await db.insert('tracks', {
        'title': station['title'],
        'artist': station['artist'],
        'song': 'RADIO',
        'audio_url': station['url'],
        'liked': 0,
        'created_at': now,
      });
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        title           TEXT NOT NULL,
        artist          TEXT NOT NULL,
        song            TEXT NOT NULL,
        audio_url       TEXT NOT NULL,
        thumbnail_path  TEXT,
        lyrics_path     TEXT,
        liked           INTEGER NOT NULL DEFAULT 0,
        liked_at        INTEGER,
        play_count      INTEGER NOT NULL DEFAULT 0,
        last_played_at  INTEGER,
        slug            TEXT,
        created_at      INTEGER NOT NULL
      )
    ''');
    // Only enforced for rows that came from a server sync (slug IS NOT NULL)
    // -- locally-added tracks have no slug and are exempt.
    await db.execute('''
      CREATE UNIQUE INDEX idx_tracks_slug ON tracks(slug) WHERE slug IS NOT NULL
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        likes      INTEGER NOT NULL DEFAULT 0,
        liked      INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_tracks (
        playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
        track_id    INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
        position    INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, track_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE search_history (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        query      TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');

    // Single-row table -- there's only ever one local profile.
    await db.execute('''
      CREATE TABLE profile (
        id           INTEGER PRIMARY KEY CHECK (id = 1),
        display_name TEXT NOT NULL,
        avatar_path  TEXT,
        server_url   TEXT
      )
    ''');

    await _seed(db);
  }

  /// One-time seed so a fresh install looks the same as the old
  /// mock_data.dart-backed app did.
  Future<void> _seed(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    Future<int> track({
      required String title,
      required String artist,
      required String song,
      required String audioUrl,
      String? thumbnailPath,
      String? lyricsPath,
      String? slug,
      bool liked = false,
      int? likedAt,
    }) {
      return db.insert('tracks', {
        'title': title,
        'artist': artist,
        'song': song,
        'audio_url': audioUrl,
        'thumbnail_path': thumbnailPath,
        'lyrics_path': lyricsPath,
        'slug': slug,
        'liked': liked ? 1 : 0,
        'liked_at': liked ? (likedAt ?? now) : null,
        'created_at': now,
      });
    }

    // These 6 used to ship as bundled Flutter assets; they now live on the
    // homelab server (see _migrateLegacyBundledTracks for the matching
    // migration on existing installs) -- slugged so a later server sync
    // recognizes them instead of duplicating.
    final summertimeSadness = await track(
      title: 'Summertime Sadness',
      artist: 'Lana Del Rey',
      song: 'SONG',
      audioUrl: '$kDefaultServerUrl/assets/audio/summertime_sadness.mp3',
      thumbnailPath: '$kDefaultServerUrl/assets/images/summertime_sadness.jpg',
      lyricsPath: '$kDefaultServerUrl/assets/lyrics/summertime_sadness.lrc',
      slug: 'summertime_sadness',
      liked: true,
      likedAt: now - 1000,
    );
    final onMyWay = await track(
      title: 'On My Way',
      artist: 'Alan Walker & Sabrina Carpenter',
      song: 'SONG',
      audioUrl: '$kDefaultServerUrl/assets/audio/on_my_way.mp3',
      thumbnailPath: '$kDefaultServerUrl/assets/images/on_my_way.jpg',
      lyricsPath: '$kDefaultServerUrl/assets/lyrics/on_my_way.lrc',
      slug: 'on_my_way',
      liked: true,
    );
    final faded = await track(
      title: 'Faded',
      artist: 'Alan Walker',
      song: 'SONG',
      audioUrl: '$kDefaultServerUrl/assets/audio/faded.mp3',
      thumbnailPath: '$kDefaultServerUrl/assets/images/faded.jpg',
      lyricsPath: '$kDefaultServerUrl/assets/lyrics/faded.lrc',
      slug: 'faded',
    );
    final genesis = await track(
      title: 'Genesis',
      artist: 'Grimes',
      song: 'SONG',
      audioUrl: '$kDefaultServerUrl/assets/audio/grimes_genesis.m4a',
      thumbnailPath: '$kDefaultServerUrl/assets/images/grimes_genesis.jpg',
      lyricsPath: '$kDefaultServerUrl/assets/lyrics/grimes_genesis.lrc',
      slug: 'grimes_genesis',
    );
    final delicateWeapon = await track(
      title: 'Delicate Weapon',
      artist: 'Grimes & Lizzy Wizzy',
      song: 'SONG',
      audioUrl: '$kDefaultServerUrl/assets/audio/grimes_lizzy_wizzy_delicate_weapon.m4a',
      thumbnailPath: '$kDefaultServerUrl/assets/images/grimes_lizzy_wizzy_delicate_weapon.jpg',
      lyricsPath: '$kDefaultServerUrl/assets/lyrics/grimes_lizzy_wizzy_delicate_weapon.lrc',
      slug: 'grimes_lizzy_wizzy_delicate_weapon',
    );
    final espresso = await track(
      title: 'Espresso',
      artist: 'Sabrina Carpenter',
      song: 'SONG',
      audioUrl: '$kDefaultServerUrl/assets/audio/sabrina_carpenter_espresso.m4a',
      thumbnailPath: '$kDefaultServerUrl/assets/images/sabrina_carpenter_espresso.jpg',
      lyricsPath: '$kDefaultServerUrl/assets/lyrics/sabrina_carpenter_espresso.lrc',
      slug: 'sabrina_carpenter_espresso',
    );

    Future<void> playlist(String name, int likes, List<int> trackIds) async {
      final id = await db.insert('playlists', {
        'name': name,
        'likes': likes,
        'created_at': now,
      });
      for (var i = 0; i < trackIds.length; i++) {
        await db.insert('playlist_tracks', {
          'playlist_id': id,
          'track_id': trackIds[i],
          'position': i,
        });
      }
    }

    await playlist('Playlist #1', 7, [summertimeSadness, onMyWay, faded]);
    await playlist('Playlist #2', 4, [onMyWay]);
    await playlist('Study', 5, [
      summertimeSadness,
      onMyWay,
      faded,
      genesis,
      delicateWeapon,
      espresso,
    ]);

    for (final query in [
      'Lana Del Rey',
      '505',
      'Do you love me back',
      'لما قلبي يدق بغار عليك',
    ]) {
      await db.insert('search_history', {'query': query, 'created_at': now});
    }

    await db.insert('profile', {'id': 1, 'display_name': 'admin', 'server_url': kDefaultServerUrl});
  }
}
