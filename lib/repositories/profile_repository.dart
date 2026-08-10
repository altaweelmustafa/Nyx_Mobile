import '../config.dart';
import '../db/app_database.dart';
import '../services/library_service.dart';

class ProfileRepository {
  Future<String> getDisplayName() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = 1', limit: 1);
    return rows.isEmpty ? 'admin' : rows.first['display_name'] as String;
  }

  Future<void> setDisplayName(String name) async {
    final db = await AppDatabase.instance.database;
    await db.update('profile', {'display_name': name}, where: 'id = 1');
    LibraryService.instance.notifyChanged();
  }

  Future<String?> getAvatarPath() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : rows.first['avatar_path'] as String?;
  }

  Future<void> setAvatarPath(String? path) async {
    final db = await AppDatabase.instance.database;
    await db.update('profile', {'avatar_path': path}, where: 'id = 1');
    LibraryService.instance.notifyChanged();
  }

  Future<String> getServerUrl() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = 1', limit: 1);
    final url = rows.isEmpty ? null : rows.first['server_url'] as String?;
    return (url == null || url.isEmpty) ? kDefaultServerUrl : url;
  }

  Future<void> setServerUrl(String url) async {
    final db = await AppDatabase.instance.database;
    await db.update('profile', {'server_url': url}, where: 'id = 1');
    LibraryService.instance.notifyChanged();
  }
}
