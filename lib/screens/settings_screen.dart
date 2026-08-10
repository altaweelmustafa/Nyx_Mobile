import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/nyx_toast.dart';
import 'sync_screen.dart';

/// Minimal settings -- just the handful of things that actually need a
/// setting: where the library syncs from, clearing cached art, and the
/// app version. No account section -- entry is gated by tailnet presence
/// (see start_screen.dart / TailnetService), not a signed-in session, so
/// there's nothing to log out of.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _clearingCache = false;

  Future<void> _clearImageCache() async {
    setState(() => _clearingCache = true);
    await DefaultCacheManager().emptyCache();
    if (!mounted) return;
    setState(() => _clearingCache = false);
    NyxToast.show(
      context,
      'Image cache cleared',
      icon: Icons.delete_sweep_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // ── App bar ────────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const _SectionLabel('LIBRARY'),
            _SettingsRow(
              icon: Icons.sync,
              title: 'Sync Library',
              subtitle: 'Server URL & catalog sync',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SyncScreen())),
            ),

            const SizedBox(height: 24),
            const _SectionLabel('STORAGE'),
            _SettingsRow(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear Image Cache',
              subtitle: 'Frees space used by cached album art',
              onTap: _clearingCache ? null : _clearImageCache,
              trailing: _clearingCache
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : null,
            ),

            const SizedBox(height: 24),
            const _SectionLabel('ABOUT'),
            const _SettingsRow(
              icon: Icons.info_outline,
              title: 'Nyx',
              subtitle: 'Version $kAppVersion',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared row/section widgets ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 11,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
