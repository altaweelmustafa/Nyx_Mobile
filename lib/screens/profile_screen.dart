import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/thumbnail.dart';
import 'playlist_screen.dart';
import 'import_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
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
                    tooltip: 'Import Track (dev)',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportScreen()),
                    ),
                    icon: const Icon(
                      Icons.library_music_outlined,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Avatar ───────────────────────────────────────────────────────
            const Center(child: CircleThumbnail(size: 100)),

            const SizedBox(height: 20),

            // ── Edit profile button ──────────────────────────────────────────
            Center(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size(160, 44),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Edit Profile'),
              ),
            ),

            const SizedBox(height: 28),

            // ── Stats row ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _StatColumn(value: '23', label: 'PLAYLISTS'),
                  _StatColumn(value: '58', label: 'FOLLOWERS'),
                  _StatColumn(value: '43', label: 'FOLLOWING'),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── Playlists heading ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Playlists',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),

            const SizedBox(height: 16),

            // ── Playlist rows ─────────────────────────────────────────────────
            ...mockPlaylists.map(
              (playlist) => GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistScreen(playlist: playlist),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Thumbnail(size: 64, borderRadius: 6),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: const TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${playlist.likes} likes',
                            style: const TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            letterSpacing: 1,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
