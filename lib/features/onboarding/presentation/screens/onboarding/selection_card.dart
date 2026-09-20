import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';

/// A rounded-rect option card with an optional leading icon and subtitle,
/// highlighting with a dark border + trailing checkmark when [selected].
/// Reused by the sex, activity-level, and goal steps.
class SelectionCard extends StatelessWidget {
  const SelectionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: selected ? AppColors.borderSelected : AppColors.border,
            width: AppSpacing.borderRegular,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: selected
                    ? AppColors.borderSelected
                    : AppColors.textDisabled,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textDisabled,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: AppTypography.bodySmall),
                  ],
                ],
              ),
            ),
            if (selected)
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.borderSelected,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: AppColors.onScrim,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
