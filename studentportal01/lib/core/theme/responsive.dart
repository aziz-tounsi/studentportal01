import 'package:flutter/material.dart';

/// Responsive design engine based on the iPhone 16 Pro Max reference canvas.
///
/// Reference specs:
/// - Reference screen width:  440.0 pt (iPhone 16 Pro Max)
/// - Reference screen height: 956.0 pt (iPhone 16 Pro Max)
///
/// Designed to scale flawlessly from the narrowest 320dp phones (e.g. small Androids,
/// iPhone SE) to 360-390dp devices (e.g. Infinix Smart 8, Galaxy A-series) up to
/// larger tablets and foldables.
class AppResponsive {
  static const double baseWidth = 440.0;
  static const double baseHeight = 956.0;

  /// Returns the proportional width scaling factor clamped between [0.72] and [1.15].
  ///
  /// - iPhone 16 Pro Max (440): 1.0
  /// - iPhone 15 / 16 (393):    ~0.89
  /// - Infinix Smart 8 (360):   ~0.82
  /// - Small Androids (320):    ~0.73
  /// - Tablets / Foldables (>600): clamped to 1.15 so components don't over-inflate.
  static double scaleW(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / baseWidth).clamp(0.72, 1.15);
  }

  /// Proportional font sizing based on iPhone 16 Pro Max reference typography.
  /// Uses a damped scaling curve (75% variance) so text scales smoothly without
  /// becoming unreadable on small screens or gigantic on tablets.
  static double sp(BuildContext context, double baseFontSize) {
    final scale = scaleW(context);
    final factor = 1.0 + (scale - 1.0) * 0.75;
    return (baseFontSize * factor).clamp(baseFontSize * 0.75, baseFontSize * 1.15);
  }

  /// Responsive component width or dimension.
  static double rw(BuildContext context, double baseDimension) {
    final scale = scaleW(context);
    return (baseDimension * scale).clamp(baseDimension * 0.70, baseDimension * 1.20);
  }

  /// Responsive page-level horizontal padding.
  /// - Smallest phones (< 360): 12.0
  /// - Infinix Smart 8 / compact phones (360 - 390): 16.0
  /// - Standard phones (390 - 430): 20.0
  /// - iPhone 16 Pro Max & wide phones (>= 430): 24.0
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 12.0;
    if (width < 390) return 16.0;
    if (width < 430) return 20.0;
    return 24.0;
  }

  /// Responsive internal card padding.
  static double cardPadding(BuildContext context, {double base = 16.0}) {
    final scale = scaleW(context);
    return (base * scale).clamp(10.0, base);
  }

  /// Check screen categories
  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 380;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static bool isShortScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 700;
}

/// Handy extension on [BuildContext] for responsive measurements.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  double get responsiveScale => AppResponsive.scaleW(this);
  double sp(double baseFontSize) => AppResponsive.sp(this, baseFontSize);
  double rw(double baseDimension) => AppResponsive.rw(this, baseDimension);
  double scaleW(double baseDimension) => AppResponsive.rw(this, baseDimension);
  double get horizontalPadding => AppResponsive.horizontalPadding(this);
  bool get isSmallScreen => AppResponsive.isSmallScreen(this);
  bool get isTablet => AppResponsive.isTablet(this);
  bool get isShortScreen => AppResponsive.isShortScreen(this);
}
