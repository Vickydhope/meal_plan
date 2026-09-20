import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/profile/domain/entities/activity_level.dart';
import 'package:meal_plan/features/profile/domain/entities/goal.dart';
import 'package:meal_plan/features/profile/domain/entities/sex.dart';
import 'package:meal_plan/features/profile/domain/usecases/calculate_calorie_target_usecase.dart';

void main() {
  const useCase = CalculateCalorieTargetUseCase();
  final now = DateTime(2026, 1, 1);

  test(
    'male, moderate activity, maintain: Mifflin-St Jeor + no adjustment',
    () {
      // 30 years old (born exactly 30 years before `now`).
      // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
      // TDEE = 1780 * 1.55 = 2759
      // target = 2759 + 0 = 2759
      final result = useCase(
        sex: Sex.male,
        dateOfBirth: DateTime(1996, 1, 1),
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        now: now,
      );

      expect(result.dailyCalorieTarget, 2759);
    },
  );

  test('female, sedentary, lose: Mifflin-St Jeor - 500', () {
    // 25 years old.
    // BMR = 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
    // TDEE = 1345.25 * 1.2 = 1614.3
    // target = 1614.3 - 500 = 1114.3 -> rounds to 1114
    final result = useCase(
      sex: Sex.female,
      dateOfBirth: DateTime(2001, 1, 1),
      heightCm: 165,
      weightKg: 60,
      activityLevel: ActivityLevel.sedentary,
      goal: Goal.lose,
      now: now,
    );

    expect(result.dailyCalorieTarget, 1114);
  });

  test('computes macros consistent with MacroSplit.fromCalories', () {
    final result = useCase(
      sex: Sex.male,
      dateOfBirth: DateTime(1996, 1, 1),
      heightCm: 180,
      weightKg: 80,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      now: now,
    );

    expect(
      result.macros.proteinGrams,
      (result.dailyCalorieTarget * 0.3 / 4).round(),
    );
    expect(
      result.macros.carbsGrams,
      (result.dailyCalorieTarget * 0.4 / 4).round(),
    );
    expect(
      result.macros.fatGrams,
      (result.dailyCalorieTarget * 0.3 / 9).round(),
    );
  });

  test('age is not incremented until the birthday has passed this year', () {
    // Born Jan 2 — as of Jan 1 `now`, the birthday hasn't happened yet this
    // year, so age should be one less than a naive year-difference.
    final dayBeforeBirthday = useCase(
      sex: Sex.male,
      dateOfBirth: DateTime(1996, 1, 2),
      heightCm: 180,
      weightKg: 80,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      now: now, // 2026-01-01, one day before the birthday -> still 29
    );
    final onBirthday = useCase(
      sex: Sex.male,
      dateOfBirth: DateTime(1996, 1, 1),
      heightCm: 180,
      weightKg: 80,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      now: now, // 2026-01-01, exactly the birthday -> 30
    );

    expect(
      dayBeforeBirthday.dailyCalorieTarget,
      lessThan(onBirthday.dailyCalorieTarget),
    );
  });
}
