import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Arabic Typography System
/// Strictly adheres to Cairo for Headers/Subtitles and Tajawal for Body/Interface
class ArabicTypography {
  // --- HEADERS & TITLES (CAIRO) ---

  /// Main Screen Headers: Cairo Bold (700) or Cairo Black (900)
  static TextStyle screenHeader({
    double fontSize = 26,
    FontWeight fontWeight = FontWeight.w900,
    Color? color,
    double? height,
    double letterSpacing = -0.5,
  }) =>
      GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Main Section / Dialog Titles: Cairo Bold (700)
  static TextStyle mainTitle({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? height,
    double letterSpacing = -0.3,
  }) =>
      GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Section Headers / Card Titles: Cairo SemiBold (600) or Cairo Bold (700)
  static TextStyle sectionHeader({
    double fontSize = 17,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? height,
    double letterSpacing = -0.2,
  }) =>
      GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Card Titles / Module Subtitles: Cairo SemiBold (600)
  static TextStyle cardTitle({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// Subtitles: Cairo SemiBold (600)
  static TextStyle subtitle({
    double fontSize = 13.5,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  // --- BODY & INTERFACE TEXT (TAJAWAL) ---

  /// Body Text / Descriptions: Tajawal Regular (400)
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.5,
  }) =>
      GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// Secondary Body / Light descriptions: Tajawal Light (300)
  static TextStyle bodyLight({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w300,
    Color? color,
    double height = 1.45,
  }) =>
      GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// Input Placeholders / Form Labels: Tajawal Regular (400)
  static TextStyle formLabel({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  /// Buttons / Action Text: Tajawal Medium (500) or Tajawal Bold (700)
  static TextStyle button({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = 0.2,
  }) =>
      GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Secondary Action / Text Button: Tajawal Medium (500)
  static TextStyle actionText({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) =>
      GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  /// Alerts & Snackbars: Tajawal Regular (400)
  static TextStyle alert({
    double fontSize = 13.5,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.4,
  }) =>
      GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// List Items / Table cells: Tajawal Regular (400)
  static TextStyle listItem({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.4,
  }) =>
      GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  // --- LOCALE-AWARE CONVENIENCE HELPERS ---

  /// Check if current locale is Arabic
  static bool isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }

  /// Adaptive Screen Header / Main Title:
  /// Uses Cairo Bold (700) / Black (900) when Arabic, standard font otherwise.
  static TextStyle headerStyle(
    BuildContext context, {
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w900,
    Color? color,
    double? height,
    double letterSpacing = -0.6,
  }) {
    if (isArabic(context)) {
      return GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Adaptive Subtitle / Section Header / Card Title:
  /// Uses Cairo SemiBold (600) / Bold (700) when Arabic, standard font otherwise.
  static TextStyle subtitleStyle(
    BuildContext context, {
    double fontSize = 13.5,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    if (isArabic(context)) {
      return GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Adaptive Body / Description / List Item / Table Cell:
  /// Uses Tajawal Regular (400) / Light (300) when Arabic with proper line-height for dense lists.
  static TextStyle bodyStyle(
    BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.45,
    double? letterSpacing,
  }) {
    if (isArabic(context)) {
      return GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Adaptive Button / Action Text:
  /// Uses Tajawal Medium (500) / Bold (700) when Arabic.
  static TextStyle buttonStyle(
    BuildContext context, {
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = 0.2,
  }) {
    if (isArabic(context)) {
      return GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
