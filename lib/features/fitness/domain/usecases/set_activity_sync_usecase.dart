import '../repositories/activity_log_repository.dart';
import '../repositories/fitness_repository.dart';

/// Turns this device's Health sync on (requesting health-store permissions
/// first, so a denial leaves it off) or off.
///
/// Turning it off also removes today's uploaded activity, so the calorie
/// budget stops including it on every device, not just this one. Earlier
/// days are kept as history.
class SetActivitySyncUseCase {
  SetActivitySyncUseCase(
    this._fitness,
    this._activityLog, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final FitnessRepository _fitness;
  final ActivityLogRepository _activityLog;
  final DateTime Function() _now;

  Future<void> call(bool enabled, {required String userId}) async {
    if (enabled) {
      await _fitness.requestPermissions();
    } else {
      await _activityLog.deleteActivity(userId, _now());
    }
    await _fitness.setSyncEnabled(enabled);
  }
}
