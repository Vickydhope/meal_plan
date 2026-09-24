import '../../../profile/domain/entities/activity_level.dart';
import '../../../profile/domain/entities/calorie_mode.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/usecases/calculate_calorie_target_usecase.dart';
import '../entities/daily_activity.dart';

/// The day's calorie budget for a user on [CalorieMode.dynamic]: the target
/// recomputed at the *sedentary* multiplier, plus the active energy
/// actually measured. The sedentary base replaces the self-reported
/// activity level (which already bakes typical exercise in), so workouts
/// aren't counted twice. It starts low and grows as the day's activity
/// syncs — that's the point of choosing dynamic over fixed.
class CalculateActivityAdjustedTargetUseCase {
  const CalculateActivityAdjustedTargetUseCase(this._calculateTarget);

  final CalculateCalorieTargetUseCase _calculateTarget;

  /// `null` — meaning "use the plan target" — if the user is on
  /// [CalorieMode.fixed] or [profile] is missing a field the target needs.
  int? call(UserProfile profile, DailyActivity activity) {
    final UserProfile(
      :calorieMode,
      :sex,
      :dateOfBirth,
      :heightCm,
      :weightKg,
      :goal,
    ) = profile;
    if (calorieMode != CalorieMode.dynamic ||
        sex == null ||
        dateOfBirth == null ||
        heightCm == null ||
        weightKg == null ||
        goal == null) {
      return null;
    }
    // ponytail: sedentary (1.2x BMR) still includes a little everyday
    // movement that the health store also counts as active energy, so this
    // slightly overstates the budget. Swap in BMR + TEF if that matters.
    final base = _calculateTarget(
      sex: sex,
      dateOfBirth: dateOfBirth,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: ActivityLevel.sedentary,
      goal: goal,
    ).dailyCalorieTarget;
    return base + activity.activeEnergyBurnedKcal;
  }
}
