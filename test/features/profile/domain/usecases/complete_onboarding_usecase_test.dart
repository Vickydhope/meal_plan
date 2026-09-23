import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/profile/domain/entities/activity_level.dart';
import 'package:meal_plan/features/profile/domain/entities/goal.dart';
import 'package:meal_plan/features/profile/domain/entities/sex.dart';
import 'package:meal_plan/features/profile/domain/repositories/profile_repository.dart';
import 'package:meal_plan/features/profile/domain/usecases/complete_onboarding_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository repository;
  late CompleteOnboardingUseCase useCase;

  setUpAll(() {
    registerFallbackValue(Sex.male);
    registerFallbackValue(ActivityLevel.moderate);
    registerFallbackValue(Goal.maintain);
    registerFallbackValue(DateTime(1996, 1, 1));
  });

  setUp(() {
    repository = _MockProfileRepository();
    useCase = CompleteOnboardingUseCase(repository);
    when(
      () => repository.completeOnboarding(
        userId: any(named: 'userId'),
        sex: any(named: 'sex'),
        dateOfBirth: any(named: 'dateOfBirth'),
        heightCm: any(named: 'heightCm'),
        weightKg: any(named: 'weightKg'),
        activityLevel: any(named: 'activityLevel'),
        goal: any(named: 'goal'),
        dailyCalorieTarget: any(named: 'dailyCalorieTarget'),
      ),
    ).thenAnswer((_) async {});
  });

  test('forwards all onboarding answers to the repository unchanged', () async {
    final dob = DateTime(1996, 1, 1);

    await useCase(
      userId: 'user-1',
      sex: Sex.male,
      dateOfBirth: dob,
      heightCm: 180,
      weightKg: 80,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      dailyCalorieTarget: 2759,
    );

    verify(
      () => repository.completeOnboarding(
        userId: 'user-1',
        sex: Sex.male,
        dateOfBirth: dob,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        dailyCalorieTarget: 2759,
      ),
    ).called(1);
  });

  test('propagates exceptions from the repository', () async {
    when(
      () => repository.completeOnboarding(
        userId: any(named: 'userId'),
        sex: any(named: 'sex'),
        dateOfBirth: any(named: 'dateOfBirth'),
        heightCm: any(named: 'heightCm'),
        weightKg: any(named: 'weightKg'),
        activityLevel: any(named: 'activityLevel'),
        goal: any(named: 'goal'),
        dailyCalorieTarget: any(named: 'dailyCalorieTarget'),
      ),
    ).thenThrow(Exception('boom'));

    expect(
      () => useCase(
        userId: 'user-1',
        sex: Sex.male,
        dateOfBirth: DateTime(1996, 1, 1),
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        dailyCalorieTarget: 2759,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
