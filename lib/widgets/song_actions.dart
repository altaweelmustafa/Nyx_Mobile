import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/track_repository.dart';
import '../theme/app_theme.dart';
import 'nyx_toast.dart';
import 'options_sheet.dart';

/// Lets the user pick one of their playlists to add [track] to, then shows
/// a confirmation toast. Shared by every "..." song menu in the app.
Future<void> addTrackToPlaylist(
  BuildContext context,
  Track track,
  PlaylistRepository playlistRepo,
) async {
  final playlists = await playlistRepo.getAll();
  if (!context.mounted) return;

  final selected = await showModalBottomSheet<Playlist>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Add to Playlist',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Text(
                'No playlists yet.',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...playlists.map(
              (p) => ListTile(
                leading: const Icon(
                  Icons.queue_music,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  p.name,
                  style: const TextStyle(
                    fontFamily: AppFonts.sans,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(p),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  if (selected == null || !context.mounted) return;
  await playlistRepo.addTrack(selected.id, track.id);
  if (!context.mounted) return;
  NyxToast.show(
    context,
    "Added to '${selected.name}'",
    icon: Icons.playlist_add_check,
  );
}

/// The standard "..." song actions sheet: like/unlike, add to playlist, and
/// a caller-supplied remove action -- label and behavior vary by context
/// (e.g. "Remove from Playlist" vs "Remove from Liked" vs "Remove from
/// Library"), which is why it's a required param rather than baked in here.
/// Fires a NyxToast for both the like toggle and the remove action; the
/// remove toast message is derived from [removeLabel] ("Remove from X" ->
/// "Removed from X") so callers don't have to pass the same wording twice.
Future<void> showSongOptionsSheet(
  BuildContext context, {
  required Track track,
  required TrackRepository trackRepo,
  required PlaylistRepository playlistRepo,
  required bool liked,
  required ValueChanged<bool> onLikeChanged,
  required String removeLabel,
  required VoidCallback onRemove,
}) {
  return showOptionsSheet(
    context,
    title: track.title,
    options: [
      SheetOption(
        icon: liked ? Icons.favorite : Icons.favorite_border,
        label: liked ? 'Unlike' : 'Like',
        onTap: () async {
          final newLiked = !liked;
          await trackRepo.setLiked(track.id, newLiked);
          onLikeChanged(newLiked);
          if (!context.mounted) return;
          NyxToast.show(
            context,
            newLiked ? 'Added to Liked Songs' : 'Removed from Liked Songs',
            icon: newLiked ? Icons.favorite : Icons.favorite_border,
          );
        },
      ),
      SheetOption(
        icon: Icons.playlist_add,
        label: 'Add to Playlist',
        onTap: () => addTrackToPlaylist(context, track, playlistRepo),
      ),
      SheetOption(
        icon: Icons.remove_circle_outline,
        label: removeLabel,
        destructive: true,
        onTap: () {
          onRemove();
          if (!context.mounted) return;
          NyxToast.show(
            context,
            removeLabel.replaceFirst('Remove', 'Removed'),
            icon: Icons.delete_outline,
          );
        },
      ),
    ],
  );
}
