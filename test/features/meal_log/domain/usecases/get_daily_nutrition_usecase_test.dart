import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/meal_log_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/get_daily_nutrition_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockMealLogRepository extends Mock implements MealLogRepository {}

MealLog _log(DateTime createdAt, int calories) => MealLog(
  id: '$createdAt',
  userId: 'user-1',
  imageUrl: null,
  mealName: 'Meal',
  totalCalories: calories,
  totalProtein: 10,
  totalCarbs: 20,
  totalFats: 5,
  healthScore: 9,
  createdAt: createdAt,
  mealType: MealType.lunch,
  items: const [],
);

void main() {
  test('queries the window and buckets logs into zero-filled days', () async {
    final repository = _MockMealLogRepository();
    final now = DateTime(2026, 9, 27, 15);
    when(
      () => repository.fetchLogsBetween(
        userId: 'user-1',
        start: DateTime(2026, 9, 21),
        end: DateTime(2026, 9, 28),
      ),
    ).thenAnswer(
      (_) async => [
        _log(DateTime(2026, 9, 27, 12), 500),
        _log(DateTime(2026, 9, 27, 8), 300),
        _log(DateTime(2026, 9, 21, 0, 5), 400),
      ],
    );

    final days = await GetDailyNutritionUseCase(repository)(
      userId: 'user-1',
      days: 7,
      now: now,
    );

    expect(days.map((d) => d.date), [
      for (var d = 21; d <= 27; d++) DateTime(2026, 9, d),
    ]);
    expect(days.map((d) => d.calories), [400, 0, 0, 0, 0, 0, 800]);
    expect(days.last.mealCount, 2);
    expect(days.last.protein, 20);
    expect(days[1].hasLogs, isFalse);
  });
}
