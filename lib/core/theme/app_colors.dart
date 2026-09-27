import 'package:flutter/material.dart';

/// Central color palette for the app, derived from the CalMia design
/// reference (design_references/meals_design_reference.webp).
///
/// Screens and shared widgets should pull colors from here instead of
/// hardcoding `Color(0x...)` literals or raw `Colors.*` values, so the
/// palette stays consistent and themeable from one place.
abstract final class AppColors {
  // Brand
  /// Deep forest green — primary buttons, progress rings, dark accents.
  static const primary = Color(0xFF2E4034);
  static const primaryDark = Color(0xFF1F2C24);
  static const primaryLight = Color(0xFF4C6350);

  /// Muted sage green used behind onboarding illustrations.
  static const sage = Color(0xFFAEBBA0);

  /// Warm orange used for the camera scan/analyzing accents.
  static const accent = Color(0xFFE8823A);

  // Surfaces
  /// App-wide scaffold background — warm off-white/cream.
  static const background = Color(0xFFEDF1EE);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFE0E3E0);

  /// Highlight band swept across [ShimmerBox] placeholders — near-white so
  /// it reads as a sheen against [surfaceMuted] rather than a new surface.
  static const shimmerHighlight = Color(0xFFF7F7F7);

  /// Near-opaque cream surface used over photos/camera previews (e.g. the
  /// detected-ingredients card), so underlying content barely shows through.
  static const surfaceTranslucent = Color(0xF2FBF8F3);

  // Text
  static const textPrimary = Color(0xFF1F2320);
  static const textSecondary = Colors.black54;
  static const textTertiary = Colors.black45;
  static const textDisabled = Colors.black38;
  static const divider = Colors.black12;

  // Borders
  /// Default subtle outline for unselected cards/inputs — light neutral,
  /// not black, so resting borders read as a hairline rather than a frame.
  static const border = Color(0xFFE3DFD8);

  /// Outline for a selected card/input. Uses the brand green instead of
  /// near-black `textPrimary` so selection reads as an accent, not a heavy
  /// outline.
  static const borderSelected = primary;

  // Macro indicator colors (protein / carbs / fat / fiber)
  static const protein = Color(0xFF4E8FD1);
  static const carbs = Color(0xFFE0973F);
  static const fat = Color(0xFF6FA35A);
  static const fiber = Color(0xFFD1564E);

  // Water intake — a muted teal: reads as water without clashing with the
  // green primary or being mistaken for [protein]'s blue.
  static const water = Color(0xFF4F8E9B);

  // Status
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFE0973F);
  static const error = Color(0xFFE53935);

  // Camera / scrim overlays (kept as pure black/white for contrast)
  static const scrim = Colors.black;
  static const onScrim = Colors.white;
}
