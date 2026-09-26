enum AppNotificationType { meal, streak }

/// A row of the in-app feed, written server-side by the `meal_logs` insert
/// trigger (see the `notifications` migration).
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
