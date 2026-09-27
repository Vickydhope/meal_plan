import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../meal_log/presentation/screens/scan_result_screen.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../providers/meal_suggestion_providers.dart';

/// Must match the `profiles.diet_notes` check constraint.
const _maxDietNotes = 200;

/// "Meal ideas for today" at the top of the Plan tab: AI suggestions for the
/// meals still to come, sized to what's left of today's budget.
class MealIdeasSection extends ConsumerWidget {
  const MealIdeasSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas = ref.watch(mealIdeasProvider);
    final notifier = ref.read(mealIdeasProvider.notifier);
    final dietNotes = ref.watch(currentUserProfileProvider).value?.dietNotes;
    final hasIdeas = ideas.value?.meals.isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.sparkles, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Meal ideas for today',
                style: AppTypography.titleMedium,
              ),
            ),
            if (hasIdeas && !ideas.isLoading)
              IconButton(
                tooltip: 'New ideas',
                icon: const Icon(LucideIcons.refresh_cw, size: 18),
                onPressed: notifier.generate,
              ),
          ],
        ),
        _DietNotesRow(notes: dietNotes),
        const SizedBox(height: 8),
        switch (ideas) {
          AsyncLoading() => const _Status(
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Planning your meals…')),
              ],
            ),
          ),
          AsyncError(:final error) => _Prompt(
            message: userMessageFor(error),
            action: 'Try again',
            onPressed: notifier.generate,
          ),
          AsyncData(value: null) => _Prompt(
            message:
                "Get meal ideas that fit what's left of today's calories"
                '${dietNotes?.trim().isNotEmpty ?? false ? ' and your diet' : ''}.',
            action: 'Suggest meals',
            onPressed: notifier.generate,
          ),
          AsyncData(value: MealIdeas(remaining: null)) => const _Status(
            child: Text(
              "You've reached today's calorie goal — nothing left to plan.",
            ),
          ),
          AsyncData(value: MealIdeas(remaining: _?, :final meals))
              when meals.isEmpty =>
            _Prompt(
              message: 'All caught up with those ideas.',
              action: 'New ideas',
              onPressed: notifier.generate,
            ),
          AsyncData(value: MealIdeas(:final remaining?, :final meals)) =>
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For the ${remaining.calories} kcal left today',
                  style: AppTypography.caption12.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final meal in meals) ...[
                  _SuggestionCard(meal: meal),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          // AsyncValue isn't sealed in this Riverpod version.
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

class _DietNotesRow extends StatelessWidget {
  const _DietNotesRow({required this.notes});

  final String? notes;

  @override
  Widget build(BuildContext context) {
    final set = notes?.trim().isNotEmpty ?? false;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        // Above AppShell's tab bar — see PlanScreen._showEditSheet.
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => _DietNotesSheet(initial: notes ?? ''),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(
              LucideIcons.salad,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                set ? 'Diet: ${notes!.trim()}' : 'Add dietary preferences',
                style: AppTypography.caption12.copyWith(
                  color: set ? AppColors.textSecondary : AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (set)
              Text(
                'Edit',
                style: AppTypography.caption12Medium.copyWith(
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DietNotesSheet extends ConsumerStatefulWidget {
  const _DietNotesSheet({required this.initial});

  final String initial;

  @override
  ConsumerState<_DietNotesSheet> createState() => _DietNotesSheetState();
}

class _DietNotesSheetState extends ConsumerState<_DietNotesSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      // Empty clears it (only non-null fields are written).
      await ref.read(updateProfileUseCaseProvider)(
        userId: userId,
        dietNotes: _controller.text.trim(),
      );
      ref.invalidate(currentUserProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, userMessageFor(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Dietary preferences', style: AppTypography.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Meal ideas will stick to these.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: _maxDietNotes,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. vegetarian, no nuts, loves Indian food',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card-shaped message.
class _Status extends StatelessWidget {
  const _Status({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle.merge(
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        child: child,
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _Status(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(LucideIcons.sparkles, size: 16),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.meal});

  final MealSuggestion meal;

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    final logged = await context.pushNamed<bool>(
      AppRoute.scanResult.name,
      extra: ScanResultArgs(suggestion: meal.toPending()),
    );
    if (logged == true) ref.read(mealIdeasProvider.notifier).markLogged(meal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = meal.toPending();
    final caption = AppTypography.caption12.copyWith(
      color: AppColors.textSecondary,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                meal.mealType.label.toUpperCase(),
                style: AppTypography.label.copyWith(color: AppColors.accent),
              ),
              const Spacer(),
              Text(
                '${pending.totalCalories} kcal',
                style: AppTypography.caption12Medium,
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 6),
          Text(meal.mealName, style: AppTypography.valueLarge),
          if (meal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meal.description, style: caption),
          ],
          const SizedBox(height: 6),
          Text(
            meal.items.map((i) => i.foodName).join(' · '),
            style: caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'P ${pending.totalProtein} g · C ${pending.totalCarbs} g · '
                  'F ${pending.totalFats} g',
                  style: AppTypography.caption11,
                ),
              ),
              TextButton.icon(
                onPressed: () => _log(context, ref),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Log'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
