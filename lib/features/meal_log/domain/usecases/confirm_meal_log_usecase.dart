import '../entities/meal_log.dart';
import '../entities/pending_meal_analysis.dart';
import '../repositories/meal_log_repository.dart';

class ConfirmMealLogUseCase {
  ConfirmMealLogUseCase(this._repository);

  final MealLogRepository _repository;

  Future<MealLog> call({
    required String userId,
    required PendingMealAnalysis analysis,
  }) {
    return _repository.saveMealLog(userId: userId, analysis: analysis);
  }
}
