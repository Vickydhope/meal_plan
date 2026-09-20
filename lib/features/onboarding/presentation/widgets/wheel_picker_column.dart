import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// A single `CupertinoPicker` column with this app's selection-row styling,
/// used side-by-side (e.g. month/day/year, or feet/inches/kg) by the
/// onboarding date-of-birth and body-metrics steps.
class WheelPickerColumn extends StatelessWidget {
  const WheelPickerColumn({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 44,
      onSelectedItemChanged: onSelectedItemChanged,
      // CupertinoPicker stacks selectionOverlay ABOVE the wheel's children,
      // so a solid fill here would paint over the selected row's text.
      // Use a border-only highlight instead so the text stays visible.
      selectionOverlay: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.scrim.withValues(alpha: 0.1), // Added opacity here
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      children: List.generate(
        itemCount,
        (i) => Center(
          child: Text(
            labelBuilder(i),
            // Explicit style rather than relying on the ambient text style:
            // CupertinoPicker falls back to a default CupertinoTheme in a
            // Material-only app, which rendered this white-on-white against
            // the picker's cream/surface background.
            style: AppTypography.titleLarge,
          ),
        ),
      ),
    );
  }
}
