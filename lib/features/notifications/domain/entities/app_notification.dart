enum AppNotificationType { meal, streak, weekly }

/// A row of the in-app feed, written server-side: meal/streak rows by the
/// `meal_logs` insert trigger, weekly ones by the `weekly_summaries` cron job.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}
