import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConsoleColors {
  static const Color background = Color(0xFF070B14);
  static const Color card = Color(0xFF0F172A);
  static const Color cardBorder = Color(0xFF1E293B);
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ConsoleTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ConsoleColors.background,
    primaryColor: ConsoleColors.primary,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0B1120),
      labelStyle: const TextStyle(color: ConsoleColors.textSecondary),
      hintStyle: const TextStyle(color: Colors.white38),
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
        borderSide: const BorderSide(color: ConsoleColors.primary, width: 1.5),
      ),
    ),
  );
}
