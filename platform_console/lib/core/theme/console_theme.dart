import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConsoleColors {
  // Brand & Primary (matching Admin Dashboard Aurora Glass kit)
  static const Color brand = Color(0xFF6D4CF6);
  static const Color brandSoft = Color(0xFFF5F3FF);
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color secondary = Color(0xFF7C3AED);

  // Light Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundAlt = Color(0xFFF0F4F8);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF9FAFB);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Sidebar (exact AdminSidebar dark navy gradient)
  static const Color sidebarBg = Color(0xFF070B14);
  static const Color sidebarText = Color(0xFF9CA3AF);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Status
  static const Color success = Color(0xFF059669);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFEFF6FF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6D4CF6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ConsoleTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: ConsoleColors.background,
    primaryColor: ConsoleColors.brand,
    colorScheme: const ColorScheme.light(
      primary: ConsoleColors.brand,
      secondary: ConsoleColors.primary,
      surface: ConsoleColors.card,
      error: ConsoleColors.error,
    ),
    textTheme: () {
      final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();
      return baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: ConsoleColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: ConsoleColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: ConsoleColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: ConsoleColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: ConsoleColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: ConsoleColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          color: ConsoleColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: ConsoleColors.textPrimary,
          height: 1.6,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: ConsoleColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: ConsoleColors.textTertiary,
          height: 1.5,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: ConsoleColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          color: ConsoleColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          color: ConsoleColors.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
    }(),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: ConsoleColors.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: ConsoleColors.textTertiary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ConsoleColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ConsoleColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ConsoleColors.brand, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
