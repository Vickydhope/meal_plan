import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/pending_meal_analysis.dart';

class MetricsSection extends StatelessWidget {
  const MetricsSection({super.key, required this.pending});

  final PendingMealAnalysis pending;

  @override
  Widget build(BuildContext context) {
    final healthColor = pending.healthScore >= 7
        ? AppColors.success
        : pending.healthScore >= 4
        ? AppColors.warning
        : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Nutrition',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        MetricCard(
          icon: LucideIcons.flame,
          iconColor: AppColors.accent,
          label: 'Calories',
          value: '${pending.totalCalories} kcal',
        ),
        MetricCard(
          icon: LucideIcons.drumstick,
          iconColor: AppColors.protein,
          label: 'Protein',
          value: '${pending.totalProtein} g',
        ),
        MetricCard(
          icon: LucideIcons.wheat,
          iconColor: AppColors.carbs,
          label: 'Carbs',
          value: '${pending.totalCarbs} g',
        ),
        MetricCard(
          icon: LucideIcons.droplet,
          iconColor: AppColors.fat,
          label: 'Fat',
          value: '${pending.totalFats} g',
        ),
        MetricCard(
          icon: LucideIcons.wand_sparkles,
          iconColor: healthColor,
          label: 'Health Rating',
          value: '${pending.healthScore}/10',
          trailing: Container(
            height: 10,
            width: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: healthColor),
          ),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
