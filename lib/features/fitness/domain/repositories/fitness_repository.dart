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

  /// Every body-weight reading taken in `[start, end]`, in no particular
  /// order. Health Connect only returns the last 30 days by default.
  Future<List<({double kg, DateTime measuredAt})>> getWeights({
    required DateTime start,
    required DateTime end,
  });

  Future<bool> isSyncEnabled();

  Future<void> setSyncEnabled(bool enabled);

  /// Asks the OS for write access to nutrition and water data; throws like
  /// [requestPermissions].
  Future<void> requestMealWritePermissions();

  Future<bool> isMealWriteBackEnabled();

  Future<void> setMealWriteBackEnabled(bool enabled);

  /// Writes [log]'s calories/macros as a meal record at its `createdAt`.
  Future<void> writeMeal(MealLog log);

  /// Removes the meal record this app wrote at [loggedAt], if any.
  Future<void> deleteMeal(DateTime loggedAt);

  /// Replaces this app's water record for [day]'s local calendar date with
  /// one holding [ml] (none when 0). Asks for write access if it's missing.
  Future<void> writeWater(DateTime day, int ml);
}
