import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/playlist.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/track_repository.dart';
import '../services/library_service.dart';
import '../widgets/nyx_toast.dart';
import '../widgets/track_thumbnail.dart';
import 'history_screen.dart';
import 'liked_tracks_screen.dart';
import 'playlist_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _trackRepo = TrackRepository();
  final _playlistRepo = PlaylistRepository();

  bool _loading = true;
  int _likedCount = 0;
  List<Playlist> _playlists = [];
  final Map<String, String?> _playlistThumbnails = {};
  LibraryService? _libSvc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _libSvc?.removeListener(_load);
    _libSvc = context.read<LibraryService>();
    _libSvc!.addListener(_load);
  }

  @override
  void dispose() {
    _libSvc?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final liked = await _trackRepo.getLiked();
    final playlists = await _playlistRepo.getLiked();
    final thumbnails = await Future.wait(
      playlists.map((p) async {
        final tracks = await _playlistRepo.getTracks(p.id);
        return MapEntry(
          p.id,
          tracks.isNotEmpty ? tracks.first.thumbnailPath : null,
        );
      }),
    );
    if (!mounted) return;
    setState(() {
      _likedCount = liked.length;
      _playlists = playlists;
      _playlistThumbnails
        ..clear()
        ..addEntries(thumbnails);
      _loading = false;
    });
  }

  Future<void> _unlikePlaylist(Playlist playlist) async {
    await _playlistRepo.setLiked(playlist.id, false);
    if (!mounted) return;
    setState(() => _playlists.removeWhere((p) => p.id == playlist.id));
    NyxToast.show(
      context,
      'Removed from Your Library',
      icon: Icons.favorite_border,
    );
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'New Playlist',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;
    final id = await _playlistRepo.create(name);
    await _load();
    if (!mounted) return;
    NyxToast.show(context, 'Playlist created', icon: Icons.playlist_add);
    final created = _playlists.firstWhere((p) => p.id == id);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: created)),
    );
    _load();
  }

  Future<void> _openLikedTracks() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LikedTracksScreen()));
    _load();
  }

  Future<void> _openHistory() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: boundToDesktopWidth(
        context,
        SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
                  children: [
                    // ── Header ────────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your Library',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'History',
                          onPressed: _openHistory,
                          icon: const Icon(
                            Icons.history,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Create Playlist',
                          onPressed: _createPlaylist,
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Liked Tracks ─────────────────────────────────────────
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openLikedTracks,
                      child: _LibraryRow(
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: AppColors.accent,
                            size: 24,
                          ),
                        ),
                        title: 'Liked Tracks',
                        subtitle: '$_likedCount TRACKS',
                        trailing: const Icon(
                          Icons.favorite,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),
                    const Divider(),
                    const SizedBox(height: 4),

                    // ── Playlists ─────────────────────────────────────────────
                    ..._playlists.map(
                      (playlist) => Column(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistScreen(playlist: playlist),
                                ),
                              );
                              _load();
                            },
                            child: _LibraryRow(
                              leading: TrackThumbnail(
                                size: 52,
                                borderRadius: 6,
                                assetPath: _playlistThumbnails[playlist.id],
                              ),
                              title: playlist.name,
                              subtitle: '${playlist.trackCount} TRACKS',
                              trailing: GestureDetector(
                                onTap: () => _unlikePlaylist(playlist),
                                child: const Icon(
                                  Icons.favorite,
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Divider(),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _LibraryRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
