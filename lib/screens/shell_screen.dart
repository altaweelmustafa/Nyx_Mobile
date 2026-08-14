import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/profile_repository.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service.dart';
import '../services/catalog_sync_service.dart';
import '../widgets/desktop_player_bar.dart';
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

  @override
  void initState() {
    super.initState();
    _autoSync();
  }

  /// Fires once whenever the app is opened (ShellScreen is the main app
  /// shell, mounted right after the login/start screen). Best-effort and
  /// silent -- if the server isn't reachable (e.g. off the tailnet), it
  /// just fails quietly exactly like it would if you never synced at all.
  /// Manual "Sync Now" in Settings still shows its own errors.
  Future<void> _autoSync() async {
    try {
      final url = await ProfileRepository().getServerUrl();
      await CatalogSyncService().syncFromServer(url);
    } catch (_) {
      // Silent -- LibraryService only fires on a successful sync with
      // actual changes, so nothing to reconcile here either.
    }
  }

  void _openPlayer() {
    final track = context.read<AudioPlayerService>().currentTrack;
    if (track == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TrackViewScreen(track: track)));
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) {
      // Sidebar nav + a full-width player bar pinned under the content,
      // instead of the phone's bottom tab bar + floating mini player.
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _Sidebar(
                    currentIndex: _currentIndex,
                    onTap: (i) => setState(() => _currentIndex = i),
                    onProfileTap: _openProfile,
                  ),
                  Expanded(child: _screens[_currentIndex]),
                ],
              ),
            ),
            DesktopPlayerBar(onTap: _openPlayer),
          ],
        ),
      );
    }

    // On the phone/tablet shell, back should feel like navigating the app,
    // not exiting it: if you're on any tab other than Home, back takes you
    // to Home first. Only pressing back while already on Home actually
    // pops the shell (i.e. exits), matching normal Android expectations.
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Page content ──────────────────────────────────────────────
            _screens[_currentIndex],

            // ── Mini player + bottom nav ─────────────────────────────────
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
      ),
    );
  }
}

// ── Sidebar nav (desktop) ────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onProfileTap;

  const _Sidebar({
    required this.currentIndex,
    required this.onTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'NYX',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _SidebarItem(
            icon: Icons.home,
            label: 'Home',
            isSelected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _SidebarItem(
            icon: Icons.library_books_outlined,
            label: 'Library',
            isSelected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _SidebarItem(
            icon: Icons.search,
            label: 'Search',
            isSelected: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          const Spacer(),
          _SidebarItem(
            icon: Icons.person,
            label: 'Profile',
            isSelected: false,
            onTap: onProfileTap,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.textPrimary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected ? AppColors.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
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
