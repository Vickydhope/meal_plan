import '../entities/meal_log.dart';
import '../entities/pending_meal_analysis.dart';

abstract class MealLogRepository {
  /// Meal logs for [userId] created on [date] (local calendar day), newest
  /// first.
  Future<List<MealLog>> fetchLogsForDate({
    required String userId,
    required DateTime date,
  });

  /// A page of [userId]'s meal logs, newest first, for multi-day/historical
  /// views (e.g. `PlanScreen`'s eventual history list) where fetching the
  /// full table per user isn't practical.
  ///
  /// [before] is a cursor: when given, only logs created strictly before it
  /// are returned, so passing the last page's oldest [MealLog.createdAt]
  /// fetches the next page. `null` fetches the most recent page.
  Future<List<MealLog>> fetchLogsPage({
    required String userId,
    DateTime? before,
    int limit = 20,
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
