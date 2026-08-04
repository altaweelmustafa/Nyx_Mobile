import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/playlist.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/thumbnail.dart';
import '../widgets/track_thumbnail.dart';
import 'edit_profile_screen.dart';
import 'jam_screen.dart';
import 'playlist_screen.dart';
import 'start_screen.dart';
import 'sync_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _playlistRepo = PlaylistRepository();
  final _profileRepo = ProfileRepository();
  List<Playlist> _playlists = [];
  final Map<String, String?> _playlistThumbnails = {};
  String _displayName = '';
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final playlists = await _playlistRepo.getAll();
    final name = await _profileRepo.getDisplayName();
    final avatarPath = await _profileRepo.getAvatarPath();
    final thumbnails = await Future.wait(
      playlists.map((p) async {
        final tracks = await _playlistRepo.getTracks(p.id);
        return MapEntry(p.id, tracks.isNotEmpty ? tracks.first.thumbnailPath : null);
      }),
    );
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
      _displayName = name;
      _avatarPath = avatarPath;
      _playlistThumbnails
        ..clear()
        ..addEntries(thumbnails);
    });
  }

  Future<void> _toggleLiked(Playlist playlist) async {
    final liked = !playlist.liked;
    await _playlistRepo.setLiked(playlist.id, liked);
    if (!mounted) return;
    setState(() {
      final i = _playlists.indexWhere((p) => p.id == playlist.id);
      if (i != -1) _playlists[i] = playlist.copyWith(liked: liked);
    });
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    _load();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Log out?', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
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
                    tooltip: 'Sync Library',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SyncScreen()),
                      );
                      _load();
                    },
                    icon: const Icon(
                      Icons.sync,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Roll',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JamScreen()),
                    ),
                    icon: const Icon(
                      Icons.podcasts,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Log out',
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Avatar ───────────────────────────────────────────────────────
            Center(child: CircleThumbnail(size: 100, imagePath: _avatarPath)),

            const SizedBox(height: 12),

            Center(
              child: Text(
                _displayName,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Google account link state ───────────────────────────────────
            Center(
              child: Consumer<AuthService>(
                builder: (context, auth, _) => auth.isSignedIn
                    ? Text(
                        auth.email!,
                        style: const TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : GestureDetector(
                        onTap: auth.isLoading ? null : () => auth.signIn().then((_) => _load()),
                        child: Text(
                          auth.isLoading ? 'Linking…' : 'Link Google account',
                          style: const TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Edit profile button ──────────────────────────────────────────
            Center(
              child: OutlinedButton(
                onPressed: _openEditProfile,
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
            Center(
              child: _StatColumn(value: '${_playlists.length}', label: 'PLAYLISTS'),
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
            ..._playlists.map(
              (playlist) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaylistScreen(playlist: playlist),
                    ),
                  );
                  _load();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      TrackThumbnail(
                        size: 84,
                        borderRadius: 8,
                        assetPath: _playlistThumbnails[playlist.id],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
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
                              '${playlist.trackCount} tracks · ${playlist.likes} likes',
                              style: const TextStyle(
                                fontFamily: AppFonts.sans,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleLiked(playlist),
                        child: Icon(
                          playlist.liked ? Icons.favorite : Icons.favorite_border,
                          color: playlist.liked ? AppColors.accent : AppColors.textSecondary,
                          size: 20,
                        ),
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
