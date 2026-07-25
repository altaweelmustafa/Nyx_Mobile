import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/thumbnail.dart';
import 'playlist_screen.dart';
import 'track_view_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Text(
              'Your Library',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),

            // ── Liked Tracks ─────────────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TrackViewScreen(track: mockTracks[0]),
                ),
              ),
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
                subtitle: '58 TRACKS',
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

            // ── Playlists ─────────────────────────────────────────────────────
            ...mockPlaylists.map(
              (playlist) => Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaylistScreen(playlist: playlist),
                      ),
                    ),
                    child: _LibraryRow(
                      leading: Thumbnail(size: 52, borderRadius: 6),
                      title: playlist.name,
                      subtitle: '${playlist.trackCount} TRACKS',
                      trailing: Icon(
                        Icons.favorite_border,
                        color: AppColors.textSecondary,
                        size: 20,
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
