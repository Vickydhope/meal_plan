import '../../../meal_log/domain/repositories/meal_log_repository.dart';
import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

/// Reschedules the next week of reminders, skipping today's lunch/dinner
/// if already logged. No-op while reminders are off.
class SyncRemindersUseCase {
  SyncRemindersUseCase(this._reminders, this._mealLogs);

  final ReminderRepository _reminders;
  final MealLogRepository _mealLogs;

  Future<void> call(String userId, {DateTime? now}) async {
    if (!await _reminders.isEnabled()) return;
    now ??= DateTime.now();
    final logs = await _mealLogs.fetchLogsForDate(userId: userId, date: now);
    await _reminders.schedule(
      upcomingReminders(
        now,
        loggedToday: {for (final log in logs) log.mealType},
      ),
    );
  }
}
