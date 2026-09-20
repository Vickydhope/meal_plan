import '../entities/meal_log.dart';
import '../repositories/meal_log_repository.dart';

class UpdateMealLogUseCase {
  UpdateMealLogUseCase(this._repository);
  final MealLogRepository _repository;

  Future<MealLog> call(MealLog log) {
    return _repository.updateMealLog(log);
  }
}
