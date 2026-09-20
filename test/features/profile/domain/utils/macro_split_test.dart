import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/profile/domain/utils/macro_split.dart';

void main() {
  test('splits calories 30/40/30 protein/carbs/fat at 4/4/9 kcal per gram', () {
    final split = MacroSplit.fromCalories(2000);

    expect(split.proteinGrams, 150); // 2000*0.3/4
    expect(split.carbsGrams, 200); // 2000*0.4/4
    expect(split.fatGrams, 67); // 2000*0.3/9 rounded
  });

  test('rounds to the nearest gram for a non-round calorie target', () {
    final split = MacroSplit.fromCalories(1864);

    expect(split.proteinGrams, 140);
    expect(split.carbsGrams, 186);
    expect(split.fatGrams, 62);
  });
}
