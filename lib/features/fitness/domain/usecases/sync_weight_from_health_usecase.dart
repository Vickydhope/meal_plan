import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../profile/domain/usecases/calculate_calorie_target_usecase.dart';
import '../repositories/fitness_repository.dart';

/// Copies the latest body weight from the health store into the profile
/// and recomputes the stored calorie target from it. Returns the synced
/// weight, or `null` if nothing changed.
///
/// Only readings taken *after* the plan was last saved are applied
/// (`onboardingCompletedAt` is re-stamped on every plan save, including
/// this one), so a manual edit in `NutritionGoalsScreen` isn't overwritten by an
/// older scale reading, and the same reading is never applied twice.
class SyncWeightFromHealthUseCase {
  const SyncWeightFromHealthUseCase({
    required FitnessRepository fitnessRepository,
    required ProfileRepository profileRepository,
    required CalculateCalorieTargetUseCase calculateTarget,
  }) : _fitness = fitnessRepository,
       _profiles = profileRepository,
       _calculate = calculateTarget;

  final FitnessRepository _fitness;
  final ProfileRepository _profiles;
  final CalculateCalorieTargetUseCase _calculate;

  Future<double?> call(String userId) async {
    if (!await _fitness.isSyncEnabled()) return null;
    final latest = await _fitness.getLatestWeight();
    if (latest == null) return null;

    final profile = await _profiles.fetchProfile(userId);
    if (profile == null) return null;
    final UserProfile(
      onboardingCompletedAt: savedAt,
      :sex,
      :dateOfBirth,
      :heightCm,
      weightKg: current,
      :activityLevel,
      :goal,
    ) = profile;
    if (savedAt == null ||
        sex == null ||
        dateOfBirth == null ||
        heightCm == null ||
        activityLevel == null ||
        goal == null) {
      return null;
    }
    if (!latest.measuredAt.isAfter(savedAt)) return null;
    if (current != null && (latest.kg - current).abs() < 0.05) return null;

    final target = _calculate(
      sex: sex,
      dateOfBirth: dateOfBirth,
      heightCm: heightCm,
      weightKg: latest.kg,
      activityLevel: activityLevel,
      goal: goal,
    ).dailyCalorieTarget;
    await _profiles.completeOnboarding(
      userId: userId,
      sex: sex,
      dateOfBirth: dateOfBirth,
      heightCm: heightCm,
      weightKg: latest.kg,
      activityLevel: activityLevel,
      goal: goal,
      dailyCalorieTarget: target,
    );
    return latest.kg;
  }
}
