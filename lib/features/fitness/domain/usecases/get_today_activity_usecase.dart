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

  /// Net walking cost above resting, in kcal per step per kg of body weight
  /// (~0.03 kcal/step at 70 kg).
  static const _kcalPerStepPerKg = 0.00045;
  static const _defaultWeightKg = 70.0;

  /// Fills in active energy from steps when the health store records steps
  /// but no active energy (common on phones without a watch). [weightKg]
  /// scales the estimate.
  static DailyActivity withEstimatedEnergy(
    DailyActivity activity, {
    double? weightKg,
  }) {
    if (activity.activeEnergyBurnedKcal != 0 || activity.steps == 0) {
      return activity;
    }
    return DailyActivity(
      date: activity.date,
      steps: activity.steps,
      activeEnergyBurnedKcal:
          (activity.steps * (weightKg ?? _defaultWeightKg) * _kcalPerStepPerKg)
              .round(),
    );
  }

  Future<DailyActivity?> call(String userId, {double? weightKg}) async {
    final today = _now();
    if (!await _fitness.isSyncEnabled()) {
      return _activityLog.fetchActivity(userId, today);
    }
    final activity = withEstimatedEnergy(
      await _fitness.getActivityForDay(today),
      weightKg: weightKg,
    );
    try {
      await _activityLog.saveActivity(userId, activity);
    } on AppException {
      // Offline etc.: still show this device's reading; the next refresh
      // uploads it.
    }
    return activity;
  }
}
