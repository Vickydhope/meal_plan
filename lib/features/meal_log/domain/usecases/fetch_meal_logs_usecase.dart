import '../entities/meal_log.dart';
import '../repositories/meal_log_repository.dart';

class FetchMealLogsUseCase {
  FetchMealLogsUseCase(this._repository);

  final MealLogRepository _repository;

  Future<List<MealLog>> call({required String userId, required DateTime date}) {
    return _repository.fetchLogsForDate(userId: userId, date: date);
  }
}
