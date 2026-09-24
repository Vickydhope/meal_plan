import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/domain/entities/activity_level.dart';
import '../../../profile/domain/entities/goal.dart';
import '../../../profile/domain/entities/sex.dart';
import '../../../profile/domain/usecases/calculate_calorie_target_usecase.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'onboarding/activity_level_step.dart';
import 'onboarding/body_metrics_step.dart';
import 'onboarding/dob_step.dart';
import 'onboarding/goal_step.dart';
import 'onboarding/onboarding_progress_bar.dart';
import 'onboarding/sex_step.dart';
import 'onboarding/step.dart';
import 'onboarding/summary_step.dart';

/// The one-time, six-step onboarding flow shown after sign-up (or on next
/// login if never completed) — see `_AuthGate` in `main.dart` for the
/// routing gate. Follows the same "computed step from a local index" shape
/// as `CameraScanScreen`/`Phase`: [_stepIndex] is the only source of truth
/// for which step is showing, and in-progress answers live as local
/// nullable fields until the final submit.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageTransitionDuration = Duration(milliseconds: 350);
  static const _pageTransitionCurve = Curves.easeInOutCubic;

  final _pageController = PageController();

  int _stepIndex = 0;

  Sex? _sex;
  DateTime? _dob;
  BodyMetrics? _bodyMetrics;
  ActivityLevel? _activityLevel;
  Goal? _goal;
  CalorieTargetResult? _summary;

  bool _submitting = false;
  String? _error;

  OnboardingStep get _step => OnboardingStep.values[_stepIndex];

  bool get _canContinue => switch (_step) {
        OnboardingStep.sex => _sex != null,
        OnboardingStep.dob => _dob != null,
        OnboardingStep.bodyMetrics => _bodyMetrics != null,
        OnboardingStep.activityLevel => _activityLevel != null,
        OnboardingStep.goal => _goal != null,
        OnboardingStep.summary => true,
      };

  void _goToStep(int index) {
    setState(() => _stepIndex = index);
    _pageController.animateToPage(
      index,
      duration: _pageTransitionDuration,
      curve: _pageTransitionCurve,
    );
  }

  void _goBack() {
    if (_stepIndex == 0) return;
    _goToStep(_stepIndex - 1);
  }

  void _continue() {
    if (!_canContinue) return;

    if (_step == OnboardingStep.goal) {
      // Compute once on entering the summary step, reused for both display
      // and the final submit's persisted target.
      _summary = ref.read(calculateCalorieTargetUseCaseProvider)(
        sex: _sex!,
        dateOfBirth: _dob!,
        heightCm: _bodyMetrics!.heightCm,
        weightKg: _bodyMetrics!.weightKg,
        activityLevel: _activityLevel!,
        goal: _goal!,
      );
    }

    if (_step == OnboardingStep.summary) {
      _completeOnboarding();
      return;
    }

    _goToStep(_stepIndex + 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null || _summary == null) return;

    setState(() {
      _submitting = true;
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
        dailyCalorieTarget: _summary!.dailyCalorieTarget,
      );
      // No Navigator call: invalidating this provider notifies
      // `RouterRefreshNotifier`, which makes the router's redirect
      // reactively swap this screen for `AppShell`.
      ref.invalidate(currentUserProfileProvider);
    } catch (err) {
      setState(() => _error = userMessageFor(err));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stepIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    if (_stepIndex > 0)
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                        onPressed: _goBack,
                      )
                    else
                      const SizedBox(width: 8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OnboardingProgressBar(
                        progress: (_stepIndex + 1) / OnboardingStep.values.length,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final step in OnboardingStep.values)
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                        child: _buildStep(step),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: (_canContinue && !_submitting) ? _continue : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onScrim,
                      disabledBackgroundColor: AppColors.textDisabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onScrim,
                            ),
                          )
                        : Text(_step == OnboardingStep.summary ? 'Get Started' : 'Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the widget for [step] — called once per step to populate the
  /// `PageView`'s children, so [OnboardingStep.summary] must tolerate being
  /// built before [_summary] is computed (it's only ever actually shown
  /// once `_continue` has set it, but `PageView` builds all children
  /// up front).
  Widget _buildStep(OnboardingStep step) {
    return switch (step) {
      OnboardingStep.sex => SexStep(
          value: _sex,
          onChanged: (value) => setState(() => _sex = value),
        ),
      OnboardingStep.dob => DobStep(
          value: _dob,
          onChanged: (value) => setState(() => _dob = value),
        ),
      OnboardingStep.bodyMetrics => BodyMetricsStep(
          value: _bodyMetrics,
          onChanged: (value) => setState(() => _bodyMetrics = value),
        ),
      OnboardingStep.activityLevel => ActivityLevelStep(
          value: _activityLevel,
          onChanged: (value) => setState(() => _activityLevel = value),
        ),
      OnboardingStep.goal => GoalStep(
          value: _goal,
          onChanged: (value) => setState(() => _goal = value),
        ),
      OnboardingStep.summary =>
        _summary == null ? const SizedBox.shrink() : SummaryStep(result: _summary!),
    };
  }
}
