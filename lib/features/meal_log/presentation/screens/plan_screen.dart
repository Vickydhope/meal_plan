import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../onboarding/presentation/screens/onboarding/activity_level_step.dart';
import '../../../onboarding/presentation/screens/onboarding/body_metrics_step.dart';
import '../../../onboarding/presentation/screens/onboarding/dob_step.dart';
import '../../../onboarding/presentation/screens/onboarding/goal_step.dart';
import '../../../onboarding/presentation/screens/onboarding/sex_step.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';
import '../../../profile/domain/entities/activity_level.dart';
import '../../../profile/domain/entities/calorie_mode.dart';
import '../../../profile/domain/entities/goal.dart';
import '../../../profile/domain/entities/sex.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/usecases/calculate_calorie_target_usecase.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/meal_log_providers.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Lets the user view their current nutrition plan and edit the answers
/// (sex, DOB, height/weight, activity level, goal) it was computed from —
/// reuses the same step widgets as `OnboardingScreen`, each opened in a
/// bottom sheet, since they're plain `value`/`onChanged` widgets with no
/// onboarding-specific coupling.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _initialized = false;

  Sex? _sex;
  DateTime? _dob;
  BodyMetrics? _bodyMetrics;
  ActivityLevel? _activityLevel;
  Goal? _goal;

  // Snapshot of the last-saved (or just-loaded) values, used to detect
  // unsaved edits so the save button can hide when there's nothing to save.
  Sex? _savedSex;
  DateTime? _savedDob;
  BodyMetrics? _savedBodyMetrics;
  ActivityLevel? _savedActivityLevel;
  Goal? _savedGoal;

  bool _saving = false;
  String? _error;

  /// Saved on its own (not via the ✓ plan save), right when it's toggled —
  /// see [_setCalorieMode].
  CalorieMode _calorieMode = CalorieMode.fixed;

  void _initFromProfile(UserProfile? profile) {
    if (_initialized || profile == null) return;
    _initialized = true;
    _sex = profile.sex;
    _dob = profile.dateOfBirth;
    _bodyMetrics = (profile.heightCm != null && profile.weightKg != null)
        ? BodyMetrics(heightCm: profile.heightCm!, weightKg: profile.weightKg!)
        : null;
    _activityLevel = profile.activityLevel;
    _goal = profile.goal;
    _calorieMode = profile.calorieMode;
    _syncSavedSnapshot();
  }

  void _syncSavedSnapshot() {
    _savedSex = _sex;
    _savedDob = _dob;
    _savedBodyMetrics = _bodyMetrics;
    _savedActivityLevel = _activityLevel;
    _savedGoal = _goal;
  }

  bool get _isComplete =>
      _sex != null &&
      _dob != null &&
      _bodyMetrics != null &&
      _activityLevel != null &&
      _goal != null;

  bool get _isDirty =>
      _sex != _savedSex ||
      _dob != _savedDob ||
      _bodyMetrics != _savedBodyMetrics ||
      _activityLevel != _savedActivityLevel ||
      _goal != _savedGoal;

  CalorieTargetResult? get _preview {
    if (!_isComplete) return null;
    return ref.read(calculateCalorieTargetUseCaseProvider)(
      sex: _sex!,
      dateOfBirth: _dob!,
      heightCm: _bodyMetrics!.heightCm,
      weightKg: _bodyMetrics!.weightKg,
      activityLevel: _activityLevel!,
      goal: _goal!,
    );
  }

  Future<T?> _showEditSheet<T>({
    required T? initial,
    required Widget Function(T? value, ValueChanged<T> onChanged) builder,
  }) {
    T? current = initial;
    return showModalBottomSheet<T>(
      context: context,
      // `go_router`'s StatefulShellRoute gives each shell branch (incl. the
      // Plan tab) its own nested Navigator inside AppShell's Scaffold body.
      // Without this, the sheet attaches to that nested Navigator and its
      // Overlay paints *behind* AppShell's bottomNavigationBar (the body
      // slot paints before the bottomNavigationBar slot) — the sheet, and
      // its Done button, render hidden behind the tab bar. Pinning to the
      // root navigator puts the sheet above the whole shell instead, same
      // as `showEditMealSheet`.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                builder(current, (v) => setSheetState(() => current = v)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: current == null
                        ? null
                        : () => Navigator.of(sheetContext).pop(current),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onScrim,
                      disabledBackgroundColor: AppColors.textDisabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.onScrim,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editSex() async {
    final result = await _showEditSheet<Sex>(
      initial: _sex,
      builder: (value, onChanged) =>
          SexStep(value: value, onChanged: onChanged, compact: true),
    );
    if (result != null) setState(() => _sex = result);
  }

  Future<void> _editDob() async {
    final result = await _showEditSheet<DateTime>(
      initial: _dob,
      builder: (value, onChanged) =>
          DobStep(value: value, onChanged: onChanged, compact: true),
    );
    if (result != null) setState(() => _dob = result);
  }

  Future<void> _editBodyMetrics() async {
    final result = await _showEditSheet<BodyMetrics>(
      initial: _bodyMetrics,
      builder: (value, onChanged) =>
          BodyMetricsStep(value: value, onChanged: onChanged, compact: true),
    );
    if (result != null) setState(() => _bodyMetrics = result);
  }

  Future<void> _editActivityLevel() async {
    final result = await _showEditSheet<ActivityLevel>(
      initial: _activityLevel,
      builder: (value, onChanged) =>
          ActivityLevelStep(value: value, onChanged: onChanged, compact: true),
    );
    if (result != null) setState(() => _activityLevel = result);
  }

  Future<void> _editGoal() async {
    final result = await _showEditSheet<Goal>(
      initial: _goal,
      builder: (value, onChanged) =>
          GoalStep(value: value, onChanged: onChanged, compact: true),
    );
    if (result != null) setState(() => _goal = result);
  }

  Future<void> _save() async {
    final preview = _preview;
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (preview == null || userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(completeOnboardingUseCaseProvider)(
        userId: userId,
        sex: _sex!,
        dateOfBirth: _dob!,
        heightCm: _bodyMetrics!.heightCm,
        weightKg: _bodyMetrics!.weightKg,
        activityLevel: _activityLevel!,
        goal: _goal!,
        dailyCalorieTarget: preview.dailyCalorieTarget,
      );
      ref.invalidate(currentUserProfileProvider);
      await ref.read(mealLogProvider.notifier).refreshProfile();
      _syncSavedSnapshot();
      if (mounted) showAppSnackBar(context, 'Plan updated');
    } catch (err) {
      setState(() => _error = userMessageFor(err));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setCalorieMode(CalorieMode mode) async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null || mode == _calorieMode) return;
    final previous = _calorieMode;
    setState(() {
      _calorieMode = mode;
      _error = null;
    });
    try {
      await ref.read(updateProfileUseCaseProvider)(
        userId: userId,
        calorieMode: mode,
      );
      ref.invalidate(currentUserProfileProvider);
      if (mounted) {
        showAppSnackBar(context, switch (mode) {
          CalorieMode.fixed =>
            'Your daily goal is now fixed at '
                '${_preview?.dailyCalorieTarget ?? '—'} kcal.',
          CalorieMode.dynamic =>
            'Your daily goal now starts at ${_basePreview?.dailyCalorieTarget ?? '—'} '
                'kcal and goes up as you burn calories.',
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _calorieMode = previous;
          _error = userMessageFor(err);
        });
      }
    }
  }

  /// The activity-based goal's starting point: the plan at a sedentary
  /// level, before any burned calories are added.
  CalorieTargetResult? get _basePreview {
    if (_sex == null || _dob == null || _bodyMetrics == null || _goal == null) {
      return null;
    }
    return ref.read(calculateCalorieTargetUseCaseProvider)(
      sex: _sex!,
      dateOfBirth: _dob!,
      heightCm: _bodyMetrics!.heightCm,
      weightKg: _bodyMetrics!.weightKg,
      activityLevel: ActivityLevel.sedentary,
      goal: _goal!,
    );
  }

  String _formatDate(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

  String _formatBodyMetrics(BodyMetrics metrics) {
    final totalInches = (metrics.heightCm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet\'$inches" · ${metrics.weightKg.round()} kg';
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    profileAsync.whenData(_initFromProfile);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Plan'),
        actions: [
          if (_saving || _isDirty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _saving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _isComplete ? _save : null,
                      icon: const Icon(Icons.check),
                      color: AppColors.primary,
                      disabledColor: AppColors.textDisabled,
                      tooltip: 'Save Changes',
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _PlanSummaryCard(
                    preview: _calorieMode == CalorieMode.dynamic
                        ? _basePreview
                        : _preview,
                    mode: _calorieMode,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tap any field below to update your goal — your '
                          'plan recalculates automatically.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Column(
                      children: [
                        _PlanFieldRow(
                          label: 'Sex',
                          value: _sex?.label ?? 'Not set',
                          onTap: _editSex,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _PlanFieldRow(
                          label: 'Date of birth',
                          value: _dob == null ? 'Not set' : _formatDate(_dob!),
                          onTap: _editDob,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _PlanFieldRow(
                          label: 'Height & weight',
                          value: _bodyMetrics == null
                              ? 'Not set'
                              : _formatBodyMetrics(_bodyMetrics!),
                          onTap: _editBodyMetrics,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _PlanFieldRow(
                          label: 'Activity level',
                          value: _activityLevel?.label ?? 'Not set',
                          onTap: _editActivityLevel,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _PlanFieldRow(
                          label: 'Goal',
                          value: _goal?.label ?? 'Not set',
                          onTap: _editGoal,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _CalorieModeSection(
                    mode: _calorieMode,
                    onChanged: _setCalorieMode,
                    fixedGoal: _preview?.dailyCalorieTarget,
                    baseGoal: _basePreview?.dailyCalorieTarget,
                    todayBudget: ref.watch(todayCalorieBudgetProvider),
                    hasActivityToday:
                        ref.watch(todayActivityProvider).value != null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed vs activity-based daily calorie goal, with a plain-language line
/// explaining what the selected option means for today's number.
class _CalorieModeSection extends StatelessWidget {
  const _CalorieModeSection({
    required this.mode,
    required this.onChanged,
    required this.fixedGoal,
    required this.baseGoal,
    required this.todayBudget,
    required this.hasActivityToday,
  });

  final CalorieMode mode;
  final ValueChanged<CalorieMode> onChanged;
  final int? fixedGoal;
  final int? baseGoal;
  final int? todayBudget;
  final bool hasActivityToday;

  String get _explanation => switch (mode) {
    CalorieMode.fixed =>
      'Your goal stays at ${fixedGoal ?? '—'} kcal every day. It already '
          "allows for your activity level, so workouts don't change it.",
    CalorieMode.dynamic when !hasActivityToday =>
      'Your goal starts at ${baseGoal ?? '—'} kcal and goes up by every '
          "calorie you burn. We haven't received any activity today, so "
          "today's goal is your usual ${fixedGoal ?? '—'} kcal. To use "
          'this, turn on Settings › Sync activity & weight from this device.',
    CalorieMode.dynamic =>
      'Your goal starts at ${baseGoal ?? '—'} kcal and goes up by every '
          'calorie you burn, using your Health app. Today so far: '
          '${todayBudget ?? '—'} kcal.',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Calorie goal', style: AppTypography.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<CalorieMode>(
            segments: [
              for (final value in CalorieMode.values)
                ButtonSegment(value: value, label: Text(value.label)),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _explanation,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.preview, required this.mode});

  final CalorieTargetResult? preview;
  final CalorieMode mode;

  @override
  Widget build(BuildContext context) {
    final result = preview;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: result == null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Fill in the fields below to see your plan.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
            )
          : Column(
              children: [
                Text(
                  '${result.dailyCalorieTarget}',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mode == CalorieMode.dynamic
                      ? 'Daily calories on an inactive day, plus what you burn'
                      : 'Daily calories',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
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
              ],
            ),
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
          style: AppTypography.titleLarge.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.label),
      ],
    );
  }
}

class _PlanFieldRow extends StatelessWidget {
  const _PlanFieldRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.titleMedium)),
            Text(value, style: AppTypography.bodyMedium),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
