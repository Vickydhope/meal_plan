import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_item.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/entities/pending_meal_analysis.dart';

void main() {
  const items = [
    MealAnalysisItem(
      foodName: 'Chicken',
      estimatedWeightG: 150,
      calories: 250,
      proteinG: 40,
      carbsG: 0,
      fatsG: 8,
    ),
    MealAnalysisItem(
      foodName: 'Rice',
      estimatedWeightG: 200,
      calories: 260,
      proteinG: 5,
      carbsG: 56,
      fatsG: 1,
    ),
  ];

  test('totals sum the adjusted (portion-scaled) values of every item', () {
    const analysis = PendingMealAnalysis(
      storagePath: 'user-1/1.jpg',
      mealName: 'Chicken & Rice',
      healthScore: 7,
      mealType: MealType.lunch,
      items: items,
    );

    expect(analysis.totalCalories, 510);
    expect(analysis.totalProtein, 45);
    expect(analysis.totalCarbs, 56);
    expect(analysis.totalFats, 9);
  });

  test('withItemPortion rescales only the targeted item and totals reflect it', () {
    const analysis = PendingMealAnalysis(
      storagePath: 'user-1/1.jpg',
      mealName: 'Chicken & Rice',
      healthScore: 7,
      mealType: MealType.lunch,
      items: items,
    );

    final halved = analysis.withItemPortion(0, 0.5);

    expect(halved.items[0].adjustedCalories, 125);
    expect(halved.items[1].adjustedCalories, 260, reason: 'untouched item is unaffected');
    expect(halved.totalCalories, 385);
  });

  test('copyWith replaces the meal name without touching items', () {
    const analysis = PendingMealAnalysis(
      storagePath: 'user-1/1.jpg',
      mealName: 'Chicken & Rice',
      healthScore: 7,
      mealType: MealType.lunch,
      items: items,
    );

    final renamed = analysis.copyWith(mealName: 'Protein Bowl');

    expect(renamed.mealName, 'Protein Bowl');
    expect(renamed.items, items);
  });
}
