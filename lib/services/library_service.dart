import 'package:flutter/foundation.dart';

/// A single cross-cutting "something in the library changed" signal --
/// every repository mutation (like, add/remove from playlist, create/rename/
/// delete playlist, play count, profile edits, catalog sync, ...) calls
/// [notifyChanged] right after its DB write. Screens that show
/// database-derived lists listen for it (same pattern already used for
/// AudioPlayerService elsewhere) and re-run their own load, so the whole
/// app stays live without every screen having to know about every other
/// screen's mutations.
///
/// Singleton (mirrors AppDatabase.instance) rather than Provider-injected,
/// because plain Dart classes without a BuildContext -- repositories,
/// AudioPlayerService, CatalogSyncService -- need to reach it too. Widgets
/// still get it through Provider (registered via .value in main.dart) so
/// context.watch/read works normally alongside every other service.
class LibraryService extends ChangeNotifier {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  void notifyChanged() => notifyListeners();
}
