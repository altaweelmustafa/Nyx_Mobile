import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web build: SQLite runs as WebAssembly in the browser, stored in IndexedDB.
Future<void> initPlatform() async {
  databaseFactory = databaseFactoryFfiWeb;
}
