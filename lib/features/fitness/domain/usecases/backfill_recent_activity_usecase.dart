import '../entities/daily_activity.dart';
import '../repositories/activity_log_repository.dart';
import '../repositories/fitness_repository.dart';
import 'get_today_activity_usecase.dart';

/// Uploads the [pastDays] days before today from this device's health
/// store. `GetTodayActivityUseCase` only uploads today, so without this,
/// days before sync was turned on or when the app wasn't opened have no
/// row, and a day's row stops at the last time the app was opened that day.
/// Ask AI's 7-day activity summary reads these rows.
///
/// Runs at most once per calendar day (per app session, since the use case
/// lives as long as its provider); a failed run is retried on the next call.
class BackfillRecentActivityUseCase {
  BackfillRecentActivityUseCase(
    this._fitness,
    this._activityLog, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final FitnessRepository _fitness;
  final ActivityLogRepository _activityLog;
  final DateTime Function() _now;

  /// Plus today = the 7 days Ask AI summarizes.
  static const pastDays = 6;

  DateTime? _lastRunDay;

  Future<void> call(String userId, {double? weightKg}) async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastRunDay == today || !await _fitness.isSyncEnabled()) return;

    // Claimed up front so overlapping calls (load + resume) don't both run.
    _lastRunDay = today;
    try {
      final activities = <DailyActivity>[];
      for (var i = 1; i <= pastDays; i++) {
        // DateTime(y, m, d - i), not subtract(Duration): stays on local
        // midnight across DST changes.
        final day = DateTime(today.year, today.month, today.day - i);
        final activity = await _fitness.getActivityForDay(day);
        // No data that day (phone off, before Health had any): skip it so
        // it doesn't count as a synced day of zero activity.
        if (activity.steps == 0 && activity.activeEnergyBurnedKcal == 0) {
          continue;
        }
        activities.add(
          GetTodayActivityUseCase.withEstimatedEnergy(
            activity,
            weightKg: weightKg,
          ),
        );
      }
      if (activities.isNotEmpty) {
        await _activityLog.saveActivities(userId, activities);
      }
    } catch (_) {
      _lastRunDay = null;
      rethrow;
    }
  }
}
