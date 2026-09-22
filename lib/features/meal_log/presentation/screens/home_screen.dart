import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/calorie_overview_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/week_strip.dart';
import '../../../profile/domain/utils/macro_split.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/meal_log.dart';
import '../../domain/entities/meal_type.dart';
import '../providers/meal_log_providers.dart';
import 'edit_meal_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealLogProvider);
    final notifier = ref.read(mealLogProvider.notifier);

    ref.listen(mealLogProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        showAppSnackBar(context, next.error!);
      }
    });

    // Past days are read-only: a meal always logs/saves with the real
    // current timestamp (see MealLogRepositoryImpl), so letting someone
    // "add" or edit food while browsing a previous day would be
    // misleading — it wouldn't actually land on that day.
    final isToday = _isSameDay(
      state.selectedDate ?? DateTime.now(),
      DateTime.now(),
    );

    // Used only to size the card's per-macro targets; not a stored target.
    final macroTargets = MacroSplit.fromCalories(state.dailyTarget);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _HomeAvatar(avatarPath: state.avatarPath),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Good morning!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            Text(
              state.username ?? 'Guest!',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.bell, size: 18),
                onPressed: () {
                  context.pushNamed(AppRoute.notifications.name);
                },
              ),
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
          onRefresh: notifier.fetchLogsForSelectedDate,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WeekStrip(
                        selectedDate: state.selectedDate ?? DateTime.now(),
                        onDateSelected: notifier.selectDate,
                      ),
                      const SizedBox(height: 16),
                      CalorieOverviewCard(
                        consumed: state.totalCaloriesToday,
                        target: state.dailyTarget,
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
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (state.isLoadingLogs)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(child: _MealSectionsShimmer()),
                )
              else if (!isToday && state.logs.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverToBoxAdapter(child: _NoMealsForDay()),
                )
              else
                for (final section in _sectionsFor(state.logs)) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MealSectionCard(
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

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
      backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
      child: avatarUrl == null
          ? const Icon(LucideIcons.circle_user, color: AppColors.textTertiary)
          : null,
    );
  }
}

/// Shown instead of the (otherwise empty, button-less) meal sections when
/// browsing a past day with nothing logged on it.
class _NoMealsForDay extends StatelessWidget {
  const _NoMealsForDay();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          LucideIcons.utensils,
          size: 28,
          color: AppColors.textDisabled,
        ),
        const SizedBox(height: 12),
        const Text(
          'No meals logged',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          "You didn't log any food on this day.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

/// Placeholder shown in place of the meal sections while
/// [MealLogState.isLoadingLogs] is true — one shimmer card per meal type,
/// mirroring [_MealSectionCard]'s shape so the layout doesn't jump once
/// real data lands.
class _MealSectionsShimmer extends StatelessWidget {
  const _MealSectionsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const ShimmerBox(width: 72, height: 72, borderRadius: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 100, height: 13),
                      SizedBox(height: 8),
                      ShimmerBox(width: 70, height: 12),
                      SizedBox(height: 8),
                      ShimmerBox(width: 140, height: 20, borderRadius: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (i < 2) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MealSection {
  const _MealSection(this.mealType, this.logs);

  final MealType mealType;
  final List<MealLog> logs;
}

/// Buckets [logs] into fixed Breakfast/Lunch/Dinner sections, plus a
/// trailing "Snack" section only when there's something to show in it.
List<_MealSection> _sectionsFor(List<MealLog> logs) {
  final byType = <MealType, List<MealLog>>{
    for (final type in MealType.values) type: [],
  };
  for (final log in logs) {
    byType[log.mealType]!.add(log);
  }

  return [
    _MealSection(MealType.breakfast, byType[MealType.breakfast]!),
    _MealSection(MealType.lunch, byType[MealType.lunch]!),
    _MealSection(MealType.dinner, byType[MealType.dinner]!),
    if (byType[MealType.snack]!.isNotEmpty)
      _MealSection(MealType.snack, byType[MealType.snack]!),
  ];
}

class _MealSectionCard extends StatelessWidget {
  const _MealSectionCard({
    required this.title,
    required this.logs,
    required this.isToday,
    required this.onLogFood,
  });

  final String title;
  final List<MealLog> logs;
  final bool isToday;
  final VoidCallback? onLogFood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isToday)
                  TextButton.icon(
                    onPressed: onLogFood,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Log Food'),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < logs.length; i++) ...[
            _DismissibleMealItemRow(log: logs[i], editable: isToday),
          ],
        ],
      ),
    );
  }
}

/// Removes [log] via [MealLogNotifier.deleteMealLog] — an immediate
/// soft-delete, both locally and in the backend — then shows an "Undo"
/// snackbar. The snackbar is purely an undo affordance here; unlike a
/// deferred-commit design, the deletion is already persisted by the time
/// it appears, so nothing reading fresh data can observe a stale total.
Future<void> _deleteMealWithUndo(
  BuildContext context,
  WidgetRef ref,
  MealLog log,
) async {
  final notifier = ref.read(mealLogProvider.notifier);
  final index = await notifier.deleteMealLog(log);
  if (index == null || !context.mounted) return;

  showUndoSnackBar(
    context,
    message: 'Removed ${log.mealName}',
    onUndo: () => notifier.restoreMealLog(index, log),
  );
}

/// Swipe-left-to-delete wrapper around a meal row — see
/// [_deleteMealWithUndo]. Past days are read-only: when [editable] is
/// `false`, swipe-to-delete is disabled entirely rather than just hidden,
/// since [Dismissible] has no built-in "disabled" state.
class _DismissibleMealItemRow extends ConsumerWidget {
  const _DismissibleMealItemRow({required this.log, required this.editable});

  final MealLog log;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!editable) return _MealItemRow(log: log, editable: false);

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteMealWithUndo(context, ref, log),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash, color: Colors.white, size: 18),
      ),
      child: _MealItemRow(log: log, editable: true),
    );
  }
}

class _MealItemRow extends ConsumerWidget {
  const _MealItemRow({required this.log, required this.editable});

  final MealLog log;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mealLogProvider.notifier);
    final imageUrl = log.imageUrl;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: editable ? () => showEditMealSheet(context, log) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 72,
                width: 72,
                child: imageUrl == null
                    ? Container(
                        color: AppColors.surfaceMuted,
                        alignment: Alignment.center,
                        child: const Icon(LucideIcons.utensils, size: 20),
                      )
                    : FutureBuilder<String>(
                        future: notifier.signedImageUrl(imageUrl),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(color: AppColors.surfaceMuted);
                          }
                          return Image.network(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.mealName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+ ${log.totalCalories} Calories',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      _MacroPill(
                        icon: LucideIcons.drumstick,
                        color: AppColors.protein,
                        text: '${log.totalProtein} g',
                      ),
                      _MacroPill(
                        icon: LucideIcons.wheat,
                        color: AppColors.carbs,
                        text: '${log.totalCarbs} g',
                      ),
                      _MacroPill(
                        icon: LucideIcons.droplet,
                        color: AppColors.fat,
                        text: '${log.totalFats} g',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
