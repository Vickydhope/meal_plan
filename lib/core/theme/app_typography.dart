import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central type scale for the app, built on the Comfortaa font used by
/// `MaterialApp.theme.textTheme` (see `main.dart`).
///
/// Screens should reuse these named styles instead of hand-rolling
/// `TextStyle(fontSize: ...)` literals, so text sizing stays consistent —
/// in particular, dialog/sheet content should use [titleLarge] or smaller
/// rather than [displayMedium]/[headlineLarge], which are sized for
/// full-screen headers.
abstract final class AppTypography {
  static TextStyle _style({
    required double fontSize,
    required FontWeight fontWeight,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.comfortaa(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Big standalone numbers, e.g. the calorie total on the plan summary card.
  static TextStyle displayLarge = _style(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );

  /// Full-screen step/page titles (onboarding flow).
  static TextStyle headlineLarge = _style(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  /// Section/sheet titles — the default for anything presented in a bottom
  /// sheet or dialog, where [headlineLarge] reads as oversized.
  static TextStyle headlineMedium = _style(
    fontSize: 19,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static TextStyle titleLarge = _style(
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  static TextStyle titleMedium = _style(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static TextStyle bodyLarge = _style(
    fontSize: 15,
    fontWeight: FontWeight.normal,
  );
  static TextStyle bodyMedium = _style(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  static TextStyle bodySmall = _style(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
  );

  /// Uppercase-style small labels (e.g. picker column headers).
  static TextStyle label = _style(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
    letterSpacing: 0.4,
  );
}
