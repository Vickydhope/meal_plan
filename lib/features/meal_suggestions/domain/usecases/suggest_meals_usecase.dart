import '../../../meal_log/domain/entities/meal_log.dart';
import '../../../meal_log/domain/entities/meal_type.dart';
import '../../../profile/domain/utils/macro_split.dart';
import '../entities/meal_suggestion.dart';
import '../repositories/meal_suggestion_repository.dart';

/// Below this, there's nothing worth planning.
const minCaloriesToPlan = 100;

class SuggestMealsUseCase {
  SuggestMealsUseCase(this._repository);

  final MealSuggestionRepository _repository;

  Future<List<MealSuggestion>> call(RemainingDay remaining) =>
      _repository.suggest(remaining);

  /// Today's budget minus what [todaysLogs] already used, and the meals
  /// still to come: main meals from the current time slot on that haven't
  /// been logged, plus a snack. `null` once under [minCaloriesToPlan] left.
  static RemainingDay? remainingDay({
    required int calorieBudget,
    required List<MealLog> todaysLogs,
    required DateTime now,
  }) {
    int left(int target, int Function(MealLog) used) {
      final eaten = todaysLogs.fold<int>(0, (sum, l) => sum + used(l));
      return target - eaten < 0 ? 0 : target - eaten;
    }

    final calories = left(calorieBudget, (l) => l.totalCalories);
    if (calories < minCaloriesToPlan) return null;

    final macros = MacroSplit.fromCalories(calorieBudget);
    final logged = todaysLogs.map((l) => l.mealType).toSet();
    final current = MealType.forTime(now);
    const mains = [MealType.breakfast, MealType.lunch, MealType.dinner];

    return RemainingDay(
      calories: calories,
      protein: left(macros.proteinGrams, (l) => l.totalProtein),
      carbs: left(macros.carbsGrams, (l) => l.totalCarbs),
      fats: left(macros.fatGrams, (l) => l.totalFats),
      mealTypes: [
        for (final type in mains.skip(mains.indexOf(current)))
          if (!logged.contains(type)) type,
        MealType.snack,
      ],
    );
  }
}
