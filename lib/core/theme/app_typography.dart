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

  /// The single biggest number on a screen — the onboarding summary's daily
  /// calorie target.
  static TextStyle displayXLarge = _style(
    fontSize: 56,
    fontWeight: FontWeight.bold,
  );

  /// The landing screen's app title.
  static TextStyle displayMedium = _style(
    fontSize: 28,
    fontWeight: FontWeight.bold,
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

  /// A prominent standalone stat number, one step down from [headlineLarge]
  /// — e.g. the calorie ring's consumed-calories figure.
  static TextStyle statValueXLarge = _style(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  /// A card-level stat number, e.g. an onboarding macro target or a
  /// nutrition-overview figure with an emphasised value.
  static TextStyle statValueLarge = _style(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  /// A smaller stat number, e.g. the calorie total on a summary card.
  static TextStyle statValue = _style(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static TextStyle titleLarge = _style(
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );

  /// A prominent title-cased value that isn't quite a heading, e.g. a meal
  /// name at the top of a sheet or result screen.
  static TextStyle titleValue = _style(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static TextStyle titleMedium = _style(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// An emphasised body value one step above [bodyMedium], e.g. a bolded
  /// count or short callout line.
  static TextStyle valueLarge = _style(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  /// A medium-weight callout line, e.g. the camera scan empty-state message.
  static TextStyle calloutMedium = _style(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
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

  /// A bolded value at [bodyMedium]'s size, e.g. a card's headline stat.
  static TextStyle valueMedium = _style(
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static TextStyle bodySmall = _style(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
  );

  /// A semibold value at [bodySmall]'s size, e.g. a card subtotal.
  static TextStyle bodySmallMedium = _style(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Uppercase-style small labels (e.g. picker column headers).
  static TextStyle label = _style(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
    letterSpacing: 0.4,
  );

  /// A small caption line, e.g. a card subtitle.
  static TextStyle caption12 = _style(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  /// A small bolded value, e.g. a health score or portion multiplier.
  static TextStyle caption12Bold = _style(
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  /// A small medium-weight value, e.g. a meal log's calorie annotation.
  static TextStyle caption12Medium = _style(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  /// The smallest regular caption, e.g. a meta line under a title.
  static TextStyle caption11 = _style(
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  /// The smallest medium-weight caption, e.g. an icon-paired tag label.
  static TextStyle caption11Medium = _style(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// The smallest caption, e.g. a unit label under a stat number.
  static TextStyle caption10 = _style(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
  );
}
