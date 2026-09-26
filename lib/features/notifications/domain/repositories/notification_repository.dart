import '../entities/app_notification.dart';

abstract class NotificationRepository {
  /// The newest notifications first.
  Future<List<AppNotification>> fetchRecent(String userId);

  Future<void> markAllRead(String userId);
}
