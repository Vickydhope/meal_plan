import '../repositories/meal_log_repository.dart';

class DeleteMealLogUseCase {
  DeleteMealLogUseCase(this._repository);

  final MealLogRepository _repository;

  Future<void> call(String logId) {
    return _repository.deleteMealLog(logId);
  }
}
