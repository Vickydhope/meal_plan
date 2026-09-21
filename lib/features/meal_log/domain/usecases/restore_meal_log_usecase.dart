import '../repositories/meal_log_repository.dart';

class RestoreMealLogUseCase {
  RestoreMealLogUseCase(this._repository);

  final MealLogRepository _repository;

  Future<void> call(String logId) {
    return _repository.restoreMealLog(logId);
  }
}
