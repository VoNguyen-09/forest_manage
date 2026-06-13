import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Color Tokens (Starbucks Design System) ──────────────────────────────────
class AppColors {
  AppColors._();

  // Primary scale
  static const Color primary   = Color(0xFF1E3932); // Tiêu đề, text chính
  static const Color secondary = Color(0xFF6F7E72); // Viền, chú thích, metadata
  static const Color tertiary  = Color(0xFF006241); // CTA duy nhất — dùng 1 action/screen

  // Surface scale
  static const Color neutral   = Color(0xFFF2F0EB); // Nền trang
  static const Color surface   = Color(0xFFFBF8F0); // Nền card / dialog
  static const Color onPrimary = Color(0xFFFBF8F0); // Text trên nền tối

  // Semantic
  static const Color error   = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color info    = Color(0xFF1565C0);
}

// ── Spacing Tokens ───────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 32;
  static const double xl = 48;
}

// ── Border Radius Tokens (Full-pill system) ──────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double sm = 100;
  static const double md = 100;
  static const double lg = 100;

  static BorderRadius get pill => BorderRadius.circular(100);
  static BorderRadius get card => BorderRadius.circular(20); // Cards use 20px
}

// ── Breakpoints ───────────────────────────────────────────────────────────────
class AppBreakpoints {
  AppBreakpoints._();
  static const double mobile = 360;
  static const double tablet = 768;
  static const double web    = 1280;
}

// ── TextTheme ────────────────────────────────────────────────────────────────
TextTheme _buildTextTheme() => TextTheme(
  displayLarge: GoogleFonts.inter(
    fontSize: 72,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.8,
    color: AppColors.primary,
  ),
  headlineLarge: GoogleFonts.inter(
    fontSize: 37,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  ),
  headlineMedium: GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  ),
  titleLarge: GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  ),
  titleMedium: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
  ),
  bodyLarge: GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.primary,
  ),
  bodyMedium: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.primary,
  ),
  bodySmall: GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
  ),
  labelSmall: GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.64,
    color: AppColors.secondary,
  ),
);

// ── Main ThemeData ────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  final textTheme = _buildTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary:          AppColors.primary,
      onPrimary:        AppColors.onPrimary,
      secondary:        AppColors.secondary,
      onSecondary:      AppColors.onPrimary,
      tertiary:         AppColors.tertiary,
      onTertiary:       AppColors.onPrimary,
      surface:          AppColors.surface,
      onSurface:        AppColors.primary,
      error:            AppColors.error,
      onError:          Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.neutral,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.onPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.tertiary,
        foregroundColor: AppColors.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.tertiary,
        side: const BorderSide(color: AppColors.tertiary),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: const BorderSide(color: AppColors.secondary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: const BorderSide(color: AppColors.secondary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: const BorderSide(color: AppColors.tertiary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      labelStyle: GoogleFonts.inter(color: AppColors.secondary),
      hintStyle: GoogleFonts.inter(color: AppColors.secondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.neutral,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.neutral,
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
    ),
  );
}
