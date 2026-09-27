import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/calorie_overview_card.dart';
import '../../../../shared/widgets/week_strip.dart';
import '../../../fitness/domain/entities/daily_activity.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';
import '../../../hydration/presentation/providers/water_providers.dart';
import '../../../hydration/presentation/widgets/water_card.dart';
import '../../../meal_suggestions/presentation/providers/meal_suggestion_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../profile/domain/entities/calorie_mode.dart';
import '../../../profile/domain/utils/macro_split.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/meal_log_providers.dart';
import 'home/meal_sections.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealLogProvider);
    final notifier = ref.read(mealLogProvider.notifier);
    final hasUnread =
        ref.watch(notificationsProvider).value?.any((n) => !n.isRead) ?? false;

    ref.listen(mealLogProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        showAppSnackBar(context, next.error!);
      }
    });

    // Subscribing also runs the sync (on launch, and again whenever
    // pull-to-refresh invalidates it).
    // Side-effect-only providers: listening keeps them alive and runs them.
    ref
      ..listen(reminderSyncProvider, (_, _) {})
      ..listen(timezoneSyncProvider, (_, _) {});
    ref.listen(healthWeightSyncProvider, (_, next) {
      // Only fresh results: loading/error states after a refresh still
      // carry the previous value, which would repeat the snackbar.
      if (next case AsyncData(value: final kg?)) {
        ref.invalidate(currentUserProfileProvider);
        showAppSnackBar(
          context,
          'Weight updated from Health: ${kg.toStringAsFixed(1)} kg',
        );
      }
    });

    // Past days are read-only: a meal always logs/saves with the real
    // current timestamp (see MealLogRepositoryImpl), so letting someone
    // "add" or edit food while browsing a previous day would be
    // misleading — it wouldn't actually land on that day.
    final selectedDay = DateUtils.dateOnly(
      state.selectedDate ?? DateTime.now(),
    );
    final isToday = DateUtils.isSameDay(selectedDay, DateTime.now());

    // Used only to size the card's per-macro targets; not a stored target.
    final dailyTarget = ref.watch(dailyCalorieTargetProvider);
    final profile = ref.watch(currentUserProfileProvider).value;
    final macroTargets = MacroSplit.fromCalories(dailyTarget);

    // Activity is only read for today, so past days keep the plain target.
    final activity = isToday ? ref.watch(todayActivityProvider).value : null;
    final todayBudget = isToday ? ref.watch(todayCalorieBudgetProvider) : null;
    final caloriesLeft =
        (todayBudget ?? dailyTarget) - state.totalCaloriesToday;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _HomeAvatar(avatarPath: profile?.avatarPath),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Good morning!',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              profile?.username ?? 'Guest!',
              style: AppTypography.titleLarge,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.chart_column, size: 18),
            tooltip: 'Trends',
            onPressed: () => context.pushNamed(AppRoute.trends.name),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.bell, size: 18),
                onPressed: () {
                  context.pushNamed(AppRoute.notifications.name);
                },
              ),
              if (hasUnread)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    height: 8,
                    width: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(LucideIcons.settings, size: 20),
              onPressed: () {
                context.pushNamed(AppRoute.settings.name);
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: .symmetric(vertical: 8),
        child: RefreshIndicator(
          onRefresh: () {
            ref
              ..invalidate(waterProvider)
              ..invalidate(todayActivityProvider)
              ..invalidate(healthWeightSyncProvider)
              ..invalidate(notificationsProvider);
            return notifier.fetchLogsForSelectedDate();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      WeekStrip(
                        selectedDate: state.selectedDate ?? DateTime.now(),
                        onDateSelected: notifier.selectDate,
                      ),

                      CalorieOverviewCard(
                        consumed: state.totalCaloriesToday,
                        target: todayBudget ?? dailyTarget,
                        macros: [
                          MacroStat(
                            label: 'Protein',
                            value: state.totalProteinToday,
                            target: macroTargets.proteinGrams,
                            icon: LucideIcons.drumstick,
                            color: AppColors.protein,
                          ),
                          MacroStat(
                            label: 'Carbs',
                            value: state.totalCarbsToday,
                            target: macroTargets.carbsGrams,
                            icon: LucideIcons.wheat,
                            color: AppColors.carbs,
                          ),
                          MacroStat(
                            label: 'Fat',
                            value: state.totalFatsToday,
                            target: macroTargets.fatGrams,
                            icon: LucideIcons.droplet,
                            color: AppColors.fat,
                          ),
                        ],
                      ),
                      if (activity != null)
                        _ActivityStats(
                          activity: activity,
                          addsToGoal:
                              ref
                                  .watch(currentUserProfileProvider)
                                  .value
                                  ?.calorieMode ==
                              CalorieMode.dynamic,
                        ),
                      if (isToday && caloriesLeft >= _ideasPromptMinCalories)
                        _MealIdeasPrompt(caloriesLeft: caloriesLeft),
                      WaterCard(
                        key: ValueKey(selectedDay),
                        day: selectedDay,
                        editable: isToday,
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (state.isLoadingLogs)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(child: MealSectionsShimmer()),
                )
              else if (!isToday && state.logs.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverToBoxAdapter(child: NoMealsForDay()),
                )
              else
                for (final section in mealSectionsFor(state.logs)) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: MealSectionCard(
                        title: section.mealType.label,
                        logs: section.logs,
                        isToday: isToday,
                        onLogFood: isToday
                            ? () => context.pushNamed(
                                AppRoute.cameraScan.name,
                                extra: section.mealType,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 150)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Steps and active energy from the health store, under the calorie card.
/// Says whether the burned calories are in the card's goal, since that's
/// what explains a goal that differs from the Plan screen's number.
class _ActivityStats extends StatelessWidget {
  const _ActivityStats({required this.activity, required this.addsToGoal});

  final DailyActivity activity;

  /// True on the activity-based calorie goal (see
  /// `CalculateActivityAdjustedTargetUseCase`).
  final bool addsToGoal;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.caption12.copyWith(
      color: AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        spacing: 6,
        children: [
          const Icon(
            LucideIcons.footprints,
            size: 14,
            color: AppColors.textSecondary,
          ),
          Text('${activity.steps} steps', style: style),
          const SizedBox(width: 10),
          const Icon(
            LucideIcons.flame,
            size: 14,
            color: AppColors.textSecondary,
          ),
          Flexible(
            child: Text(
              addsToGoal
                  ? '${activity.activeEnergyBurnedKcal} kcal burned · added to '
                        "today's goal"
                  : '${activity.activeEnergyBurnedKcal} kcal burned',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Below this, a "get meal ideas" nudge isn't worth the space.
const _ideasPromptMinCalories = 300;

/// "650 kcal left · Get meal ideas" under today's calorie card: starts
/// generating (unless ideas for about this much are already there) and
/// switches to the Plan tab, where they show.
class _MealIdeasPrompt extends ConsumerWidget {
  const _MealIdeasPrompt({required this.caloriesLeft});

  final int caloriesLeft;

  void _open(BuildContext context, WidgetRef ref) {
    final ideas = ref.read(mealIdeasProvider);
    final plannedFor = ideas.value?.remaining?.calories;
    final stale = plannedFor == null || (plannedFor - caloriesLeft).abs() > 100;
    if (!ideas.isLoading && stale) {
      ref.read(mealIdeasProvider.notifier).generate();
    }
    context.goNamed(AppRoute.plan.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Its own Material rather than an Ink decoration, so the background
    // moves with the row when the list relays out (see the Plan tab).
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$caloriesLeft kcal left · '),
                      TextSpan(
                        text: 'Get meal ideas',
                        style: AppTypography.bodySmallMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app-bar avatar — matches `ProfileScreen._ProfileAvatar`'s
/// placeholder/real-photo logic, just smaller and without the upload
/// affordance.
class _HomeAvatar extends ConsumerWidget {
  const _HomeAvatar({required this.avatarPath});

  final String? avatarPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = avatarPath;
    final avatarUrl = path == null
        ? null
        : ref.watch(avatarRepositoryProvider).publicUrlFor(path);

    return CircleAvatar(
      backgroundColor: AppColors.surface,
      backgroundImage: avatarUrl == null
          ? null
          : CachedNetworkImageProvider(avatarUrl),
      child: avatarUrl == null
          ? const Icon(LucideIcons.circle_user, color: AppColors.textTertiary)
          : null,
    );
  }
}
