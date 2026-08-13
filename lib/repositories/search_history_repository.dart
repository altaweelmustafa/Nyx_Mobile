import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../services/library_service.dart';

class SearchHistoryRepository {
  Future<List<String>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('search_history', orderBy: 'id DESC');
    return rows.map((r) => r['query'] as String).toList();
  }

  /// Records [query] as a search, most-recent-first (see getAll's
  /// `id DESC` order). `query` is UNIQUE, so re-searching the same term
  /// just bumps its position instead of creating a duplicate entry.
  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final db = await AppDatabase.instance.database;
    await db.insert(
      'search_history',
      {'query': trimmed, 'created_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    LibraryService.instance.notifyChanged();
  }

  Future<void> remove(String query) async {
    final db = await AppDatabase.instance.database;
    await db.delete('search_history', where: 'query = ?', whereArgs: [query]);
    LibraryService.instance.notifyChanged();
  }
}
