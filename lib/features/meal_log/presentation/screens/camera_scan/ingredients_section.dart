import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../domain/entities/meal_analysis_item.dart';
import '../../providers/meal_log_providers.dart';
import 'fade_slide_in.dart';

/// Best-effort category badge derived purely from the ingredient's name —
/// there's no backend category field, so this is just enough to echo the
/// reference design's per-item icon, not a real classifier.
String? _categoryFor(String foodName) {
  final name = foodName.toLowerCase();
  const categories = {
    'Fruit': [
      'berry',
      'berries',
      'apple',
      'banana',
      'orange',
      'grape',
      'mango',
    ],
    'Dairy': ['cheese', 'milk', 'yogurt', 'cream', 'butter'],
    'Grain': ['bread', 'rice', 'pasta', 'oat', 'muffin', 'cereal'],
    'Protein': ['chicken', 'beef', 'egg', 'fish', 'tofu', 'pork', 'salmon'],
    'Vegetable': [
      'spinach',
      'broccoli',
      'carrot',
      'lettuce',
      'tomato',
      'pepper',
    ],
  };
  for (final entry in categories.entries) {
    if (entry.value.any(name.contains)) return entry.key;
  }
  return null;
}

/// Ingredient portion multipliers offered by each card's inline stepper.
const portionSteps = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Removes ingredient [index] via [scanSessionProvider], then surfaces either
/// an "Undo" snackbar (restoring it via [ScanSessionNotifier.restoreItem]) or,
/// if the removal was refused for being the meal's last ingredient, a
/// validation message — a meal can't end up with zero ingredients.
void _removeWithUndo(BuildContext context, WidgetRef ref, int index) {
  final notifier = ref.read(scanSessionProvider.notifier);
  final removed = notifier.removeItem(index);

  if (removed == null) {
    showAppSnackBar(context, 'A meal needs at least one ingredient.');
    return;
  }

  showUndoSnackBar(
    ScaffoldMessenger.of(context),
    message: 'Removed ${removed.foodName}',
    onUndo: () => notifier.restoreItem(index, removed),
  );
}

/// Renders the detected ingredients as a list of cards. When [editable] is
/// true (the settled "reviewing" phase), each card gets an inline portion
/// stepper and a remove button wired straight to [scanSessionProvider] — there
/// is no separate edit sheet, editing happens in place.
class IngredientsSection extends ConsumerWidget {
  const IngredientsSection({
    super.key,
    required this.items,
    required this.isStreaming,
    this.editable = false,
  });

  final List<MealAnalysisItem> items;
  final bool isStreaming;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detected ingredients', style: AppTypography.titleMedium),
        const SizedBox(height: 10),
        for (final entry in items.asMap().entries) ...[
          FadeSlideIn(
            child: editable
                ? DismissibleIngredientCard(
                    itemKey: '${entry.value.foodName}_${entry.key}',
                    item: entry.value,
                    canDismiss: items.length > 1,
                    onPortionChanged: (portion) => ref
                        .read(scanSessionProvider.notifier)
                        .setItemPortion(entry.key, portion),
                    onRemove: () => _removeWithUndo(context, ref, entry.key),
                  )
                : IngredientCard(item: entry.value),
          ),
          const SizedBox(height: 10),
        ],
        if (isStreaming) const AnalyzingNextCard(),
      ],
    );
  }
}

/// Swipe-left-to-delete wrapper around an editable [IngredientCard] —
/// mirrors `_DismissibleMealItemRow` in `home_screen.dart`. Reused by
/// `edit_meal_sheet.dart` for the same swipe-to-delete ingredient rows
/// there. [canDismiss] blocks the swipe up front (bouncing the card back)
/// when this is the meal's last ingredient, instead of letting it
/// disappear and only then getting refused.
class DismissibleIngredientCard extends StatelessWidget {
  const DismissibleIngredientCard({
    super.key,
    required this.itemKey,
    required this.item,
    required this.canDismiss,
    required this.onPortionChanged,
    required this.onRemove,
  });

  final String itemKey;
  final MealAnalysisItem item;
  final bool canDismiss;
  final ValueChanged<double> onPortionChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(itemKey),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (canDismiss) return true;
        showAppSnackBar(context, 'A meal needs at least one ingredient.');
        return false;
      },
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash, color: Colors.white, size: 18),
      ),
      child: IngredientCard(
        item: item,
        onPortionChanged: onPortionChanged,
        onRemove: onRemove,
        showRemoveButton: false,
      ),
    );
  }
}

/// A detected-ingredient card. The portion stepper is collapsed by default
/// (an [AnimatedSize] under the macro pills) and only revealed by tapping
/// the tune icon — [onPortionChanged] being non-null both gates the toggle
/// button's visibility and enables it.
class IngredientCard extends StatefulWidget {
  const IngredientCard({
    super.key,
    required this.item,
    this.onPortionChanged,
    this.onRemove,
    this.showRemoveButton = true,
  });

  final MealAnalysisItem item;
  final ValueChanged<double>? onPortionChanged;
  final VoidCallback? onRemove;

  /// Hidden when the card is already wrapped in a swipe-to-delete
  /// [Dismissible] (the camera-scan review flow) — [onRemove] is still
  /// wired through in that case, just triggered by the swipe instead.
  final bool showRemoveButton;

  @override
  State<IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<IngredientCard> {
  bool _editingPortion = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final category = _categoryFor(item.foodName);
    var stepIndex = portionSteps.indexWhere(
      (s) => (s - item.portion).abs() < 0.001,
    );
    if (stepIndex < 0) stepIndex = portionSteps.indexOf(1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.leaf,
                  color: AppColors.accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.foodName,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      category != null
                          ? '$category · ${item.adjustedWeightG.round()}g'
                          : '${item.adjustedWeightG.round()}g',
                      style: AppTypography.caption12.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.adjustedCalories.round()} kcal',
                style: AppTypography.bodySmallMedium,
              ),
              if (widget.onPortionChanged != null)
                IconButton(
                  icon: Icon(
                    _editingPortion
                        ? LucideIcons.chevron_up
                        : LucideIcons.sliders_horizontal,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  tooltip: _editingPortion ? 'Hide portion' : 'Edit portion',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _editingPortion = !_editingPortion),
                ),
              if (widget.onRemove != null && widget.showRemoveButton)
                IconButton(
                  icon: const Icon(
                    LucideIcons.trash,
                    color: AppColors.error,
                    size: 18,
                  ),
                  tooltip: 'Remove ingredient',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MacroPill(
                icon: LucideIcons.drumstick,
                color: AppColors.protein,
                text: '${item.adjustedProteinG.round()}g',
              ),
              _MacroPill(
                icon: LucideIcons.wheat,
                color: AppColors.carbs,
                text: '${item.adjustedCarbsG.round()}g',
              ),
              _MacroPill(
                icon: LucideIcons.droplet,
                color: AppColors.fat,
                text: '${item.adjustedFatsG.round()}g',
              ),
            ],
          ),
          if (widget.onPortionChanged != null) ...{
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _editingPortion
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Portion',
                              style: AppTypography.caption12.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            Text(
                              '${portionSteps[stepIndex]}x',
                              style: AppTypography.caption12Bold.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: AppColors.primary,
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            inactiveTrackColor: AppColors.divider,
                          ),
                          child: Slider(
                            value: stepIndex.toDouble(),
                            min: 0,
                            padding: .symmetric(vertical: 8, horizontal: 8),
                            max: (portionSteps.length - 1).toDouble(),
                            divisions: portionSteps.length - 1,
                            label: '${portionSteps[stepIndex]}x',
                            onChanged: (value) => widget.onPortionChanged!(
                              portionSteps[value.round()],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          },
        ],
      ),
    );
  }
}

/// Matches the macro-pill style used by meal cards on the home screen
/// (`_MacroPill` in `home_screen.dart`) so an ingredient's nutrients read
/// the same way there as they do mid-scan.
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

class AnalyzingNextCard extends StatelessWidget {
  const AnalyzingNextCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cravia is analyzing next ingredient...',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Identifying category',
                  style: AppTypography.caption11.copyWith(
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
