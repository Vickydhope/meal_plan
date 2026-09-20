import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../profile/domain/usecases/calculate_calorie_target_usecase.dart';
import 'onboarding_header.dart';

class SummaryStep extends StatelessWidget {
  const SummaryStep({super.key, required this.result});

  final CalorieTargetResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingHeader(
          title: 'Your plan is ready!',
          subtitle: "Here's your personalized nutrition plan.",
        ),
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Text(
                '${result.dailyCalorieTarget}',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your Daily calories',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroStat(
                label: 'Protein',
                value: result.macros.proteinGrams,
                color: AppColors.protein,
              ),
              _MacroStat(
                label: 'Carbs',
                value: result.macros.carbsGrams,
                color: AppColors.carbs,
              ),
              _MacroStat(
                label: 'Fat',
                value: result.macros.fatGrams,
                color: AppColors.fat,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "You're all set! Start scanning your meals and we'll help you "
          'stay on track.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value}g',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
