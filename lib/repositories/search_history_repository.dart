import '../db/app_database.dart';
import '../services/library_service.dart';

class SearchHistoryRepository {
  Future<List<String>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('search_history', orderBy: 'id');
    return rows.map((r) => r['query'] as String).toList();
  }

  Future<void> remove(String query) async {
    final db = await AppDatabase.instance.database;
    await db.delete('search_history', where: 'query = ?', whereArgs: [query]);
    LibraryService.instance.notifyChanged();
  }
}
