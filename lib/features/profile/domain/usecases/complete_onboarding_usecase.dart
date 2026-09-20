import '../entities/activity_level.dart';
import '../entities/goal.dart';
import '../entities/sex.dart';
import '../repositories/profile_repository.dart';

class CompleteOnboardingUseCase {
  const CompleteOnboardingUseCase(this._repository);

  final ProfileRepository _repository;

  Future<void> call({
    required String userId,
    required Sex sex,
    required DateTime dateOfBirth,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required Goal goal,
    required int dailyCalorieTarget,
  }) {
    return _repository.completeOnboarding(
      userId: userId,
      sex: sex,
      dateOfBirth: dateOfBirth,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      goal: goal,
      dailyCalorieTarget: dailyCalorieTarget,
    );
  }
}
