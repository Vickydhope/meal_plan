import '../entities/daily_activity.dart';

/// Activity stored on the backend, one row per user per local day, so it's
/// visible on every device signed in to the account (and to Ask AI) — not
/// just the one whose health store it came from.
abstract class ActivityLogRepository {
  Future<void> saveActivity(String userId, DailyActivity activity);

  /// The stored activity for [day]'s local calendar date, or `null`.
  Future<DailyActivity?> fetchActivity(String userId, DateTime day);

  Future<void> deleteActivity(String userId, DateTime day);
}
