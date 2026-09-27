import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_suggestions/domain/usecases/suggest_meals_usecase.dart';

MealLog _log(MealType type, int kcal, {int protein = 0}) => MealLog(
  id: '$type',
  userId: 'u',
  imageUrl: null,
  mealName: 'M',
  totalCalories: kcal,
  totalProtein: protein,
  totalCarbs: 0,
  totalFats: 0,
  healthScore: 5,
  createdAt: DateTime(2026, 9, 28, 8),
  mealType: type,
  items: const [],
);

void main() {
  test('plans the rest of the day from the current slot on', () {
    final day = SuggestMealsUseCase.remainingDay(
      calorieBudget: 2000,
      todaysLogs: [_log(MealType.breakfast, 500, protein: 40)],
      now: DateTime(2026, 9, 28, 13),
    )!;

    expect(day.calories, 1500);
    // Budget 2000 → 150 g protein (30%), minus 40 eaten.
    expect(day.protein, 110);
    expect(day.mealTypes, [MealType.lunch, MealType.dinner, MealType.snack]);
  });

  test('skips mains already logged and slots already past', () {
    final day = SuggestMealsUseCase.remainingDay(
      calorieBudget: 2000,
      todaysLogs: [_log(MealType.lunch, 700)],
      now: DateTime(2026, 9, 28, 12),
    )!;

    // Breakfast is past, lunch is logged.
    expect(day.mealTypes, [MealType.dinner, MealType.snack]);
  });

  test('late evening with dinner logged leaves just a snack', () {
    final day = SuggestMealsUseCase.remainingDay(
      calorieBudget: 2000,
      todaysLogs: [_log(MealType.dinner, 900)],
      now: DateTime(2026, 9, 28, 21),
    )!;

    expect(day.mealTypes, [MealType.snack]);
  });

  test('nothing to plan once the budget is (nearly) used', () {
    expect(
      SuggestMealsUseCase.remainingDay(
        calorieBudget: 2000,
        todaysLogs: [_log(MealType.lunch, 1950)],
        now: DateTime(2026, 9, 28, 13),
      ),
      isNull,
    );
  });

  test('over-eaten macros floor at zero', () {
    final day = SuggestMealsUseCase.remainingDay(
      calorieBudget: 2000,
      todaysLogs: [_log(MealType.breakfast, 600, protein: 400)],
      now: DateTime(2026, 9, 28, 9),
    )!;

    expect(day.protein, 0);
  });
}
