import '../entities/meal_log.dart';
import '../repositories/meal_log_repository.dart';

/// Fetches one page of a user's meal-log history, for multi-day/historical
/// views — distinct from [FetchMealLogsUseCase]'s single-calendar-day fetch.
class FetchMealLogsPageUseCase {
  FetchMealLogsPageUseCase(this._repository);

  final MealLogRepository _repository;

  Future<List<MealLog>> call({
    required String userId,
    DateTime? before,
    int limit = 20,
  }) {
    return _repository.fetchLogsPage(
      userId: userId,
      before: before,
      limit: limit,
    );
  }
}
