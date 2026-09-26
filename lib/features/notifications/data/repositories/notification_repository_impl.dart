import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

/// `notifications` table access, talking to [SupabaseClient] directly —
/// two queries don't need a separate datasource class.
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _table = 'notifications';
  static final _types = AppNotificationType.values.asNameMap();

  @override
  Future<List<AppNotification>> fetchRecent(String userId) async {
    try {
      final rows = await _client
          .from(_table)
          .select('id, type, title, body, created_at, read_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return [
        for (final row in rows)
          // Skips types this build doesn't know, so a new server-side type
          // can't break the whole feed for older app versions.
          if (_types[row['type']] case final type?)
            AppNotification(
              id: row['id'] as String,
              type: type,
              title: row['title'] as String,
              body: row['body'] as String,
              createdAt: DateTime.parse(row['created_at'] as String),
              readAt: DateTime.tryParse(row['read_at'] as String? ?? ''),
            ),
      ];
    } catch (err) {
      throw MealLogPersistenceException('Failed to load notifications: $err');
    }
  }

  @override
  Future<void> markAllRead(String userId) async {
    try {
      await _client
          .from(_table)
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (err) {
      throw MealLogPersistenceException('Failed to update notifications: $err');
    }
  }
}
