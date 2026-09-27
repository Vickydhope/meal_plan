import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../shared/widgets/shimmer_box.dart';
import '../../../domain/entities/meal_log.dart';
import '../../../domain/entities/meal_type.dart';
import '../../providers/meal_log_providers.dart';
import '../edit_meal_sheet.dart';

/// Shown instead of the (otherwise empty, button-less) meal sections when
/// browsing a past day with nothing logged on it.
class NoMealsForDay extends StatelessWidget {
  const NoMealsForDay({super.key});

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
        Text('No meals logged', style: AppTypography.titleMedium),
        const SizedBox(height: 4),
        Text(
          "You didn't log any food on this day.",
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Placeholder shown in place of the meal sections while
/// [MealLogState.isLoadingLogs] is true — one shimmer card per meal type,
/// mirroring [MealSectionCard]'s shape so the layout doesn't jump once
/// real data lands.
class MealSectionsShimmer extends StatelessWidget {
  const MealSectionsShimmer({super.key});

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

class MealSection {
  const MealSection(this.mealType, this.logs);

  final MealType mealType;
  final List<MealLog> logs;
}

/// Buckets [logs] into fixed Breakfast/Lunch/Dinner sections, plus a
/// trailing "Snack" section only when there's something to show in it.
List<MealSection> mealSectionsFor(List<MealLog> logs) {
  final byType = <MealType, List<MealLog>>{
    for (final type in MealType.values) type: [],
  };
  for (final log in logs) {
    byType[log.mealType]!.add(log);
  }

  return [
    MealSection(MealType.breakfast, byType[MealType.breakfast]!),
    MealSection(MealType.lunch, byType[MealType.lunch]!),
    MealSection(MealType.dinner, byType[MealType.dinner]!),
    if (byType[MealType.snack]!.isNotEmpty)
      MealSection(MealType.snack, byType[MealType.snack]!),
  ];
}

class MealSectionCard extends StatelessWidget {
  const MealSectionCard({
    super.key,
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
                Text(title, style: AppTypography.valueLarge),
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
  // Grabbed before the await: the row (and its context) is often gone
  // by then — rows aren't keyed, so deleting a section's last one
  // disposes it.
  final messenger = ScaffoldMessenger.of(context);
  final index = await notifier.deleteMealLog(log);
  if (index == null || !messenger.mounted) return;

  showUndoSnackBar(
    messenger,
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
      onTap: () => editable
          ? showEditMealSheet(context, log)
          : _showRelogSheet(context, ref, log),
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
                          // Keyed by storage path, not the signed URL,
                          // so the disk cache survives URL re-signing.
                          return CachedNetworkImage(
                            imageUrl: snapshot.data!,
                            cacheKey: imageUrl,
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
                    style: AppTypography.bodySmallMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+ ${log.totalCalories} Calories',
                    style: AppTypography.caption12Medium,
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

/// Past days are read-only, so tapping one of their meals offers to log it
/// again today instead of editing it.
Future<void> _showRelogSheet(BuildContext context, WidgetRef ref, MealLog log) {
  return showModalBottomSheet(
    context: context,
    // Above AppShell's tab bar — see showEditMealSheet.
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(log.mealName, style: AppTypography.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${log.totalCalories} Calories · ${log.mealType.label}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(LucideIcons.repeat, size: 16),
              label: const Text('Log again today'),
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final saved = await ref
                    .read(mealLogProvider.notifier)
                    .relogMeal(log);
                if (saved != null && context.mounted) {
                  showAppSnackBar(
                    context,
                    "Added ${log.mealName} to today's ${log.mealType.label.toLowerCase()}",
                  );
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
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
          Text(text, style: AppTypography.caption11),
        ],
      ),
    );
  }
}
