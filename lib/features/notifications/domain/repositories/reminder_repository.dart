import '../entities/reminder.dart';

/// On-device scheduled meal/weigh-in reminders.
abstract class ReminderRepository {
  Future<bool> isEnabled();

  /// Enabling asks for notification permission first and throws
  /// `NotificationPermissionDeniedException` if it's refused; disabling
  /// cancels everything scheduled.
  Future<void> setEnabled(bool enabled);

  /// Replaces every scheduled reminder with [reminders], in the device's
  /// current time zone.
  Future<void> schedule(List<Reminder> reminders);
}
