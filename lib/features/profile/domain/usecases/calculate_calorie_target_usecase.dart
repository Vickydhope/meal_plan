import '../entities/activity_level.dart';
import '../entities/goal.dart';
import '../entities/sex.dart';
import '../utils/macro_split.dart';

class CalorieTargetResult {
  const CalorieTargetResult({
    required this.dailyCalorieTarget,
    required this.macros,
  });

  final int dailyCalorieTarget;
  final MacroSplit macros;
}

/// Computes a daily calorie target from onboarding answers using the
/// Mifflin-St Jeor BMR formula, scaled by activity level (TDEE) and
/// adjusted for the user's goal. Pure Dart — no Flutter/Supabase imports,
/// so it's usable both by the onboarding summary screen (display) and at
/// submit time (the value actually persisted).
class CalculateCalorieTargetUseCase {
  const CalculateCalorieTargetUseCase();

  CalorieTargetResult call({
    required Sex sex,
    required DateTime dateOfBirth,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required Goal goal,
    DateTime? now,
  }) {
    final age = _ageInYears(dateOfBirth, now ?? DateTime.now());
    final bmr = sex == Sex.male
        ? 10 * weightKg + 6.25 * heightCm - 5 * age + 5
        : 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    final tdee = bmr * activityLevel.multiplier;
    final target = (tdee + goal.calorieAdjustment).round();

    return CalorieTargetResult(
      dailyCalorieTarget: target,
      macros: MacroSplit.fromCalories(target),
    );
  }

  int _ageInYears(DateTime dob, DateTime now) {
    var age = now.year - dob.year;
    final hadBirthdayThisYear =
        now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthdayThisYear) age--;
    return age;
  }
}
