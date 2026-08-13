import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/track_repository.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/collection_header.dart';
import '../widgets/nyx_toast.dart';
import '../widgets/options_sheet.dart';
import '../widgets/song_actions.dart';
import '../widgets/track_row_tap.dart';
import '../widgets/track_thumbnail.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final _playlistRepo = PlaylistRepository();
  final _trackRepo = TrackRepository();

  List<Track> _tracks = [];
  bool _loading = true;
  late String _name;
  LibraryService? _libSvc;

  @override
  void initState() {
    super.initState();
    _name = widget.playlist.name;
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
    final tracks = await _playlistRepo.getTracks(widget.playlist.id);
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loading = false;
    });
  }

  Future<void> _removeFromPlaylist(int index) async {
    final track = _tracks[index];
    await _playlistRepo.removeTrack(widget.playlist.id, track.id);
    if (!mounted) return;
    setState(() => _tracks.removeAt(index));
  }

  void _showSongOptions(int index) {
    final track = _tracks[index];
    showSongOptionsSheet(
      context,
      track: track,
      trackRepo: _trackRepo,
      playlistRepo: _playlistRepo,
      liked: track.liked,
      onLikeChanged: (liked) {
        if (!mounted) return;
        setState(() => _tracks[index] = track.copyWith(liked: liked));
      },
      removeLabel: 'Remove from Playlist',
      onRemove: () => _removeFromPlaylist(index),
    );
  }

  void _showOptions() {
    showOptionsSheet(
      context,
      title: _name,
      options: [
        SheetOption(
          icon: Icons.share_outlined,
          label: 'Share Playlist',
          onTap: () => SharePlus.instance.share(
            ShareParams(text: 'Check out my playlist "$_name" on Nyx'),
          ),
        ),
        SheetOption(
          icon: Icons.edit_outlined,
          label: 'Rename Playlist',
          onTap: _renamePlaylist,
        ),
        SheetOption(
          icon: Icons.delete_outline,
          label: 'Delete Playlist',
          destructive: true,
          onTap: _deletePlaylist,
        ),
      ],
    );
  }

  Future<void> _renamePlaylist() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Rename Playlist',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(border: OutlineInputBorder()),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || !mounted) return;
    await _playlistRepo.rename(widget.playlist.id, newName);
    if (!mounted) return;
    setState(() => _name = newName);
    NyxToast.show(context, 'Playlist renamed', icon: Icons.edit_outlined);
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Playlist?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '"$_name" will be permanently deleted.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _playlistRepo.delete(widget.playlist.id);
    if (!mounted) return;
    NyxToast.show(context, 'Playlist deleted', icon: Icons.delete_outline);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentTrackId = context.watch<AudioPlayerService>().currentTrack?.id;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showOptions,
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // ── Playlist header ──────────────────────────────────────────
            CollectionHeader(
              title: _name,
              subtitle: '${_tracks.length} TRACKS',
              thumbnailPath: _tracks.isNotEmpty ? _tracks.first.thumbnailPath : null,
              onPlayAll: _tracks.isEmpty
                  ? null
                  : () => handleTrackTap(context, _tracks, 0, isPersonalPlaylist: true),
            ),

            // ── Track list ─────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _tracks.length,
                      itemBuilder: (context, i) {
                        final track = _tracks[i];
                        final isNowPlaying = track.id == currentTrackId;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => handleTrackTap(
                            context,
                            _tracks,
                            i,
                            isPersonalPlaylist: true,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                // Thumbnail
                                TrackThumbnail(
                                  size: 46,
                                  assetPath: track.thumbnailPath,
                                  borderRadius: 6,
                                ),
                                const SizedBox(width: 14),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        style: TextStyle(
                                          fontFamily: AppFonts.sans,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: isNowPlaying
                                              ? AppColors.accent
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        track.artist,
                                        style: const TextStyle(
                                          fontFamily: AppFonts.sans,
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Song options
                                GestureDetector(
                                  onTap: () => _showSongOptions(i),
                                  child: const Icon(
                                    Icons.more_vert,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
