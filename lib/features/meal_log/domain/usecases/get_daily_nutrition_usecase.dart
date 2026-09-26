import '../entities/meal_log.dart';
import '../repositories/meal_log_repository.dart';

/// One local calendar day's summed meal totals.
class DailyNutrition {
  const DailyNutrition({
    required this.date,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.mealCount = 0,
  });

  final DateTime date;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final int mealCount;

  bool get hasLogs => mealCount > 0;
}

/// Per-day totals for the last [days] local calendar days ending today,
/// oldest first. Days with nothing logged are included with zero totals, so
/// the result always has exactly [days] entries.
class GetDailyNutritionUseCase {
  GetDailyNutritionUseCase(this._repository);

  final MealLogRepository _repository;

  Future<List<DailyNutrition>> call({
    required String userId,
    required int days,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    // DateTime(y, m, d ± n) rather than Duration(days: n), so DST days
    // (23h/25h) still land on local midnight.
    final start = DateTime(today.year, today.month, today.day - days + 1);
    final end = DateTime(today.year, today.month, today.day + 1);

    final logs = await _repository.fetchLogsBetween(
      userId: userId,
      start: start,
      end: end,
    );

    final byDay = <DateTime, List<MealLog>>{};
    for (final log in logs) {
      final t = log.createdAt.toLocal();
      (byDay[DateTime(t.year, t.month, t.day)] ??= []).add(log);
    }

    return [
      for (var i = 0; i < days; i++)
        _sum(
          DateTime(start.year, start.month, start.day + i),
          byDay[DateTime(start.year, start.month, start.day + i)] ?? const [],
        ),
    ];
  }

  DailyNutrition _sum(DateTime date, List<MealLog> logs) => DailyNutrition(
    date: date,
    calories: logs.fold(0, (sum, log) => sum + log.totalCalories),
    protein: logs.fold(0, (sum, log) => sum + log.totalProtein),
    carbs: logs.fold(0, (sum, log) => sum + log.totalCarbs),
    fats: logs.fold(0, (sum, log) => sum + log.totalFats),
    mealCount: logs.length,
  );
}
