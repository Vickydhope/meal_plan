import '../../../../core/error/app_exception.dart';
import '../entities/daily_activity.dart';
import '../repositories/activity_log_repository.dart';
import '../repositories/fitness_repository.dart';

/// Today's activity for the account, or `null` if none has been synced.
///
/// A device with Health sync on reads its health store and uploads the
/// result; every other device reads what was uploaded. So activity from
/// the phone shows up on a tablet signed in to the same account.
class GetTodayActivityUseCase {
  GetTodayActivityUseCase(
    this._fitness,
    this._activityLog, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final FitnessRepository _fitness;
  final ActivityLogRepository _activityLog;
  final DateTime Function() _now;

  Future<DailyActivity?> call(String userId) async {
    final today = _now();
    if (!await _fitness.isSyncEnabled()) {
      return _activityLog.fetchActivity(userId, today);
    }
    final activity = await _fitness.getActivityForDay(today);
    try {
      await _activityLog.saveActivity(userId, activity);
    } on AppException {
      // Offline etc.: still show this device's reading; the next refresh
      // uploads it.
    }
    return activity;
  }
}
