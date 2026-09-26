import '../entities/meal_analysis_item.dart';
import '../entities/meal_log.dart';
import '../entities/pending_meal_analysis.dart';
import '../repositories/meal_log_repository.dart';

/// Saves a copy of [MealLog] as a new log timestamped now, with the same
/// meal type, ingredients and photo — no upload or analysis needed. The
/// photo is shared, which is safe: saved meals' images are only removed by
/// the orphan cleanup, and only once no `meal_logs` row references them.
class RelogMealUseCase {
  RelogMealUseCase(this._repository);

  final MealLogRepository _repository;

  Future<MealLog> call({required String userId, required MealLog log}) {
    return _repository.saveMealLog(
      userId: userId,
      analysis: PendingMealAnalysis(
        storagePath: log.imageUrl,
        mealName: log.mealName,
        healthScore: log.healthScore,
        mealType: log.mealType,
        // Totals are derived from items, so a legacy log without a
        // breakdown gets one item carrying its saved totals.
        items: log.items.isNotEmpty
            ? log.items
            : [
                MealAnalysisItem(
                  foodName: log.mealName,
                  estimatedWeightG: 0,
                  calories: log.totalCalories.toDouble(),
                  proteinG: log.totalProtein.toDouble(),
                  carbsG: log.totalCarbs.toDouble(),
                  fatsG: log.totalFats.toDouble(),
                ),
              ],
      ),
    );
  }
}
