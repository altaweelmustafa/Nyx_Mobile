import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/home_mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'track_view_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  final _screens = const [HomeScreen(), LibraryScreen(), SearchScreen()];

  void _openPlayer() {
    final track = context.read<AudioPlayerService>().currentTrack;
    if (track == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackViewScreen(track: track)),
    );
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Page content ──────────────────────────────────────────────────
          _screens[_currentIndex],

          // ── Mini player + bottom nav ───────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Home tab → full PDF-style card
                // All other tabs → compact pill player
                if (_currentIndex == 0)
                  HomeMiniPlayer(onTap: _openPlayer)
                else
                  MiniPlayer(onTap: _openPlayer),
                _BottomNav(
                  currentIndex: _currentIndex,
                  onTap: (i) => setState(() => _currentIndex = i),
                  onProfileTap: _openProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom navigation bar ──────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onProfileTap;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Home
          _NavItem(
            icon: Icons.home,
            isSelected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          // Library
          _NavItem(
            icon: Icons.library_books_outlined,
            isSelected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          // Search
          _NavItem(
            icon: Icons.search,
            isSelected: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          // Profile avatar
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(
                  color: currentIndex == 3
                      ? AppColors.accent
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          size: 26,
        ),
      ),
    );
  }
}
