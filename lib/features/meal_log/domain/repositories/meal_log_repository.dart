import '../entities/meal_log.dart';
import '../entities/pending_meal_analysis.dart';

abstract class MealLogRepository {
  /// Meal logs for [userId] created on [date] (local calendar day), newest
  /// first.
  Future<List<MealLog>> fetchLogsForDate({
    required String userId,
    required DateTime date,
  });

  /// Persists [analysis] as a new meal log for [userId].
  Future<MealLog> saveMealLog({
    required String userId,
    required PendingMealAnalysis analysis,
  });

  /// Deletes the meal log with [logId].
  Future<void> deleteMealLog(String logId);

  /// Reverses [deleteMealLog] for [logId].
  Future<void> restoreMealLog(String logId);

  /// Persists edits to an existing meal log, returning the updated entity.
  Future<MealLog> updateMealLog(MealLog log);
}
