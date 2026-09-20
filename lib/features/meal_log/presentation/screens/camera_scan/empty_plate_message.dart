import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/app_colors.dart';

/// Fills the space below the photo frame before analysis has started
/// ([Phase.idle]/[Phase.captured]), so the screen doesn't read as
/// unfinished while there are no ingredients to show yet. Matches
/// `design_references/scan screen message.png`.
class EmptyPlateMessage extends StatelessWidget {
  const EmptyPlateMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.chef_hat,
              size: 32,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 20),
            Text(
              'Your plate is empty for now',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textTertiary,
                fontWeight: .w500
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan any meal to instantly track calories',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _FeatureChip(
                  icon: LucideIcons.zap,
                  label: 'Instant calories',
                ),
                _FeatureChip(
                  icon: LucideIcons.chart_pie,
                  label: 'Full macros',
                ),
                _FeatureChip(
                  icon: LucideIcons.list_checks,
                  label: 'Ingredient breakdown',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single "what scanning gets you" pill under the empty-state message.
class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
