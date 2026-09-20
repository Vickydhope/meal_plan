/// Spacing, corner-radius, and border-width scale shared across the app.
///
/// Screens and shared widgets should pull from here instead of hardcoding
/// magic numbers for padding/`SizedBox`/`BorderRadius.circular`, so spacing
/// stays consistent as new features are added.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  // Corner radii
  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 20.0;
  static const radiusXl = 24.0;
  static const radiusFull = 999.0;

  // Border widths — kept thin; use [AppColors.border]/[AppColors.borderSelected]
  // for the color so edges read as subtle dividers, not heavy outlines.
  static const borderThin = 1.0;
  static const borderRegular = 1.5;
}
