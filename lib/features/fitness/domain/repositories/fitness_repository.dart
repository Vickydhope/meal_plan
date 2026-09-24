import '../../../meal_log/domain/entities/meal_log.dart';
import '../entities/daily_activity.dart';

/// Read-only access to the platform health store, plus the user's opt-in
/// for syncing it (HealthKit hides whether read access was granted, so the
/// opt-in can't be derived from permissions alone).
abstract class FitnessRepository {
  /// Asks the OS for read access to steps, active energy and weight. Throws
  /// [HealthStoreUnavailableException] if the store isn't installed
  /// (Health Connect on Android) and [HealthPermissionDeniedException] if
  /// the user declines.
  Future<void> requestPermissions();

  Future<DailyActivity> getActivityForDay(DateTime day);

  /// The most recent body-weight reading from the last 30 days (Health
  /// Connect's default read window), or `null` if there is none.
  Future<({double kg, DateTime measuredAt})?> getLatestWeight();

  Future<bool> isSyncEnabled();

  Future<void> setSyncEnabled(bool enabled);

  /// Asks the OS for write access to nutrition data; throws like
  /// [requestPermissions].
  Future<void> requestMealWritePermissions();

  Future<bool> isMealWriteBackEnabled();

  Future<void> setMealWriteBackEnabled(bool enabled);

  /// Writes [log]'s calories/macros as a meal record at its `createdAt`.
  Future<void> writeMeal(MealLog log);

  /// Removes the meal record this app wrote at [loggedAt], if any.
  Future<void> deleteMeal(DateTime loggedAt);
}
