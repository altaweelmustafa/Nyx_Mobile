import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';

class ArtistProfile {
  final String name;
  final String? photoPath;
  final String? bio;

  const ArtistProfile({required this.name, this.photoPath, this.bio});

  factory ArtistProfile.fromMap(Map<String, Object?> map) => ArtistProfile(
    name: map['name'] as String,
    photoPath: map['photo_path'] as String?,
    bio: map['bio'] as String?,
  );
}

/// Real artist entities (photo/bio), synced from orc's `/api/artists` by
/// CatalogSyncService. Separate from track_artists (which just records
/// which tracks belong to which artist name) since profile metadata syncing
/// is independent of that membership.
class ArtistRepository {
  Future<ArtistProfile?> getByName(String name) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('artists', where: 'name = ?', whereArgs: [name]);
    return rows.isEmpty ? null : ArtistProfile.fromMap(rows.first);
  }

  Future<List<ArtistProfile>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('artists', orderBy: 'name');
    return rows.map(ArtistProfile.fromMap).toList();
  }

  Future<void> upsert({
    required String name,
    String? photoPath,
    String? bio,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('artists', {
      'name': name,
      'photo_path': photoPath,
      'bio': bio,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
