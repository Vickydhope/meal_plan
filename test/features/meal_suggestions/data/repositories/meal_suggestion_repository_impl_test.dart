import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_suggestions/data/repositories/meal_suggestion_repository_impl.dart';

void main() {
  test('parses suggestions into reviewable meals', () {
    final meals = MealSuggestionRepositoryImpl.suggestionsFromJson({
      'meals': [
        {
          'meal_type': 'dinner',
          'meal_name': 'Dal Rice',
          'description': 'Comforting.',
          'health_score': 8,
          'items': [
            {
              'food_name': 'Dal',
              'estimated_weight_g': 200,
              'calories': 300,
              'protein_g': 18,
              'carbs_g': 40,
              'fats_g': 6,
            },
            {'food_name': 'Rice', 'calories': 200.4},
          ],
        },
      ],
    });

    final dinner = meals.single;
    expect(dinner.mealType, MealType.dinner);
    expect(dinner.items, hasLength(2));
    final pending = dinner.toPending();
    expect(pending.storagePath, isNull);
    expect(pending.totalCalories, 500);
    expect(pending.totalProtein, 18);
  });

  test('a malformed response is a user-facing error', () {
    expect(
      () => MealSuggestionRepositoryImpl.suggestionsFromJson({'nope': 1}),
      throwsA(isA<MealSuggestionException>()),
    );
  });
}
