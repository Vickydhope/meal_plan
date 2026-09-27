import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';
import '../../../meal_suggestions/presentation/widgets/meal_ideas_section.dart';
import '../../../profile/domain/entities/calorie_mode.dart';
import '../../../profile/domain/utils/macro_split.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// The Plan tab: what to eat (AI meal ideas for the rest of today) first,
/// then a summary of the targets they're planned against. The targets
/// themselves are edited on `NutritionGoalsScreen`.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Plan'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: const [
            MealIdeasSection(),
            SizedBox(height: 24),
            _GoalsCard(),
          ],
        ),
      ),
    );
  }
}

class _GoalsCard extends ConsumerWidget {
  const _GoalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final target = profile?.dailyCalorieTarget;
    final activityBased = profile?.calorieMode == CalorieMode.dynamic;
    final today = activityBased ? ref.watch(todayCalorieBudgetProvider) : null;
    final caption = AppTypography.caption12.copyWith(
      color: AppColors.textSecondary,
    );

    // Its own Material, not an Ink decoration: Ink is painted by an
    // ancestor Material and was left behind when the list above relaid out.
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(AppRoute.nutritionGoals.name),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                LucideIcons.target,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nutrition goals', style: AppTypography.valueLarge),
                    const SizedBox(height: 4),
                    if (target == null)
                      Text('Set up your daily targets', style: caption)
                    else ...[
                      Text(
                        [
                          '$target kcal a day',
                          ?profile?.goal?.label,
                          if (activityBased) 'activity-based',
                        ].join(' · '),
                        style: caption,
                      ),
                      if (today != null && today != target)
                        Text(
                          'Today: $today kcal with activity',
                          style: caption,
                        ),
                      Text(_macros(target), style: AppTypography.caption11),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _macros(int calories) {
    final m = MacroSplit.fromCalories(calories);
    return 'P ${m.proteinGrams} g · C ${m.carbsGrams} g · F ${m.fatGrams} g';
  }
}
