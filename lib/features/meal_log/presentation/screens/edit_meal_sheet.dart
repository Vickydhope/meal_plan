import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/meal_analysis_item.dart';
import '../../domain/entities/meal_log.dart';
import '../providers/meal_log_providers.dart';
import 'camera_scan/ingredients_section.dart' show DismissibleIngredientCard;

/// Opens the meal-editing bottom sheet for [log], saving any ingredient
/// quantity changes via [MealLogNotifier.updateMealLog] when the user taps
/// Save — nutrient totals are always derived from the ingredient list, not
/// edited directly. Meal name and meal type are not editable here.
Future<void> showEditMealSheet(BuildContext context, MealLog log) {
  return showModalBottomSheet(
    context: context,
    // `go_router`'s StatefulShellRoute gives the Home tab its own nested
    // Navigator inside AppShell's Scaffold body. Without this, the sheet
    // attaches to that nested Navigator and its Overlay paints *behind*
    // AppShell's bottomNavigationBar (the body slot paints before the
    // bottomNavigationBar slot) — the sheet can render partly hidden
    // behind the tab bar. Pinning to the root navigator puts the sheet
    // above the whole shell instead, same as the Plan tab's edit sheets
    // (see PlanScreen._showEditSheet).
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditMealSheet(log: log),
  );
}

class _EditMealSheet extends ConsumerStatefulWidget {
  const _EditMealSheet({required this.log});

  final MealLog log;

  @override
  ConsumerState<_EditMealSheet> createState() => _EditMealSheetState();
}

class _EditMealSheetState extends ConsumerState<_EditMealSheet> {
  late List<MealAnalysisItem> _items = [...widget.log.items];
  bool _saving = false;

  // Undo affordance for a removed ingredient, rendered inline in the sheet
  // itself rather than via a SnackBar: `showModalBottomSheet` attaches to
  // go_router's per-tab nested Navigator, whose ScaffoldMessenger-driven
  // SnackBar renders on the *underlying* page's Scaffold — behind this
  // sheet's own modal route, i.e. invisible. An inline banner is always
  // part of the sheet's own widget tree, so it can't end up behind it.
  MealAnalysisItem? _pendingRemovedItem;
  int? _pendingRemovedIndex;
  Timer? _undoTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  /// Live totals from [_items] (portion-adjusted) — falls back to the
  /// meal's originally saved totals when there's no ingredient breakdown to
  /// derive them from (legacy logs).
  int get _totalCalories => _items.isEmpty
      ? widget.log.totalCalories
      : _items.fold(0.0, (sum, item) => sum + item.adjustedCalories).round();
  int get _totalProtein => _items.isEmpty
      ? widget.log.totalProtein
      : _items.fold(0.0, (sum, item) => sum + item.adjustedProteinG).round();
  int get _totalCarbs => _items.isEmpty
      ? widget.log.totalCarbs
      : _items.fold(0.0, (sum, item) => sum + item.adjustedCarbsG).round();
  int get _totalFats => _items.isEmpty
      ? widget.log.totalFats
      : _items.fold(0.0, (sum, item) => sum + item.adjustedFatsG).round();

  void _setPortion(int index, double portion) {
    setState(() {
      _items = [..._items];
      _items[index] = _items[index].copyWith(portion: portion);
    });
  }

  /// Removes ingredient [index], showing an inline "Removed X · Undo" banner
  /// for 3 seconds before the removal is final. Only called from
  /// [DismissibleIngredientCard.onDismissed], which already refuses the
  /// swipe (via `canDismiss`) when this would empty the list.
  void _removeItem(int index) {
    final removed = _items[index];
    _undoTimer?.cancel();
    setState(() {
      _items = [..._items]..removeAt(index);
      _pendingRemovedItem = removed;
      _pendingRemovedIndex = index;
    });
    _undoTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _pendingRemovedItem = null;
        _pendingRemovedIndex = null;
      });
    });
  }

  void _undoRemove() {
    final removed = _pendingRemovedItem;
    final index = _pendingRemovedIndex;
    if (removed == null || index == null) return;
    _undoTimer?.cancel();
    setState(() {
      _items = [..._items]..insert(index, removed);
      _pendingRemovedItem = null;
      _pendingRemovedIndex = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = MealLog(
      id: widget.log.id,
      userId: widget.log.userId,
      imageUrl: widget.log.imageUrl,
      mealName: widget.log.mealName,
      totalCalories: widget.log.totalCalories,
      totalProtein: widget.log.totalProtein,
      totalCarbs: widget.log.totalCarbs,
      totalFats: widget.log.totalFats,
      healthScore: widget.log.healthScore,
      createdAt: widget.log.createdAt,
      mealType: widget.log.mealType,
      items: _items,
    );

    await ref.read(mealLogProvider.notifier).updateMealLog(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MealThumbnail(imageUrl: widget.log.imageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.log.mealName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_totalCalories Calories',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _NutrientPill(
                              icon: LucideIcons.drumstick,
                              color: AppColors.protein,
                              text: '${_totalProtein}g protein',
                            ),
                            _NutrientPill(
                              icon: LucideIcons.wheat,
                              color: AppColors.carbs,
                              text: '${_totalCarbs}g carbs',
                            ),
                            _NutrientPill(
                              icon: LucideIcons.droplet,
                              color: AppColors.fat,
                              text: '${_totalFats}g fat',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Ingredients',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: _items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No ingredient breakdown was saved for this meal.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            DismissibleIngredientCard(
                              itemKey: '${_items[index].foodName}_$index',
                              item: _items[index],
                              canDismiss: _items.length > 1,
                              onPortionChanged: (portion) =>
                                  _setPortion(index, portion),
                              onRemove: () => _removeItem(index),
                            ),
                      ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _pendingRemovedItem == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _UndoBanner(
                          message: 'Removed ${_pendingRemovedItem!.foodName}',
                          onUndo: _undoRemove,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_saving || _items.isEmpty) ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline "Removed X · Undo" row shown in place of a SnackBar — see the
/// comment on `_EditMealSheetState`'s undo fields for why.
class _UndoBanner extends StatelessWidget {
  const _UndoBanner({required this.message, required this.onUndo});

  final String message;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.onScrim, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(foregroundColor: AppColors.sage),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }
}

/// The meal's logged photo, matching the thumbnail style used by
/// `_MealItemRow` on the home screen — signed on demand since Storage URLs
/// aren't public.
class _MealThumbnail extends ConsumerWidget {
  const _MealThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mealLogProvider.notifier);
    final imageUrl = this.imageUrl;

    return ClipRRect(
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
                  return Image.network(snapshot.data!, fit: BoxFit.cover);
                },
              ),
      ),
    );
  }
}

class _NutrientPill extends StatelessWidget {
  const _NutrientPill({
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
