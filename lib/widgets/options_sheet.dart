import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SheetOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
}

/// A bottom sheet listing tappable options -- the shared look for every
/// "..." menu in the app (playlist actions, track actions, etc).
Future<void> showOptionsSheet(
  BuildContext context, {
  String? title,
  required List<SheetOption> options,
}) async {
  final selected = await showModalBottomSheet<SheetOption>(
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
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ...options.map(
            (o) => ListTile(
              leading: Icon(
                o.icon,
                color: o.destructive ? Colors.redAccent : AppColors.textSecondary,
              ),
              title: Text(
                o.label,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  color: o.destructive ? Colors.redAccent : AppColors.textPrimary,
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(o),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  selected?.onTap();
}
