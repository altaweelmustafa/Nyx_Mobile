import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const background = Color(0xFF111111);
  static const surface = Color(0xFF1A1A1A);
  static const surfaceHigh = Color(0xFF222222);
  static const textPrimary = Color(0xFFD9D9D9);
  static const textSecondary = Color(0xFFB3B3B3);
  static const accent = Color(0xFFF19EDC);
  static const placeholder = Color(0xFFD9D9D9); // grey thumbnails
  static const divider = Color(0xFF2A2A2A);
}

class AppFonts {
  static const sans = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
  static const arabic = 'Cairo';

  /// Glyphs the Latin faces above don't cover (Arabic script, etc.) fall
  /// back to this automatically -- attach it to any TextStyle that doesn't
  /// already inherit it from the theme's DefaultTextStyle.
  static const fallback = [arabic];
}

/// Single width breakpoint gating every desktop-only layout change (sidebar
/// nav, content max-width, card grids). No Android phone -- portrait or
/// landscape -- reaches 900 logical px, and the Linux/Windows GTK window
/// defaults to 1280, so this cleanly separates "phone" from "desktop
/// window" without any per-screen logic.
class AppBreakpoints {
  static const desktop = 900.0;
}

extension ResponsiveContext on BuildContext {
  bool get isDesktop => MediaQuery.sizeOf(this).width >= AppBreakpoints.desktop;
}

/// Width [boundToDesktopWidth] caps content at on desktop -- a phone-shaped
/// column looks intentional at this width instead of stretching
/// edge-to-edge into a 1280px window.
const kDesktopContentMaxWidth = 1040.0;

/// Caps [child] at [kDesktopContentMaxWidth] and centers it on desktop --
/// a no-op below the breakpoint, so phone screens are unaffected.
Widget boundToDesktopWidth(BuildContext context, Widget child) {
  if (!context.isDesktop) return child;
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kDesktopContentMaxWidth),
      child: child,
    ),
  );
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        surface: AppColors.surface,
        onPrimary: AppColors.background,
        onSurface: AppColors.textPrimary,
        outline: AppColors.divider,
      ),
      fontFamily: AppFonts.sans,
      fontFamilyFallback: AppFonts.fallback,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      textTheme: const TextTheme(
        // "For You", "Your Library", page headings
        headlineLarge: TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        // "Suggestions", section titles
        headlineMedium: TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        // Track names, playlist names
        titleLarge: TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        // Artist names, subtitles
        bodyLarge: TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        bodyMedium: TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        // Track counts — uses Mono
        labelSmall: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        floatingLabelAlignment: FloatingLabelAlignment.start,
        labelStyle: const TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 11,
          letterSpacing: 1.4,
          color: AppColors.textSecondary,
        ),
        // typed text style
        hintStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        // top padding so label sits in top-left, typed text below it
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
