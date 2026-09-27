import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../meal_log/presentation/providers/meal_log_providers.dart';
import '../../data/repositories/local_reminder_repository_impl.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/usecases/sync_reminders_usecase.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// The feed. Refetched when meals change (the meal_logs insert trigger
/// writes feed rows) and by invalidation (pull-to-refresh, leaving
/// `NotificationsScreen`) — no realtime subscription.
final notificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  ref.watch(mealLogChangesProvider);
  final userId = ref.watch(authUserIdProvider).valueOrNull;
  if (userId == null) return const [];
  return ref.watch(notificationRepositoryProvider).fetchRecent(userId);
});

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => LocalReminderRepositoryImpl(
    FlutterLocalNotificationsPlugin(),
    SharedPreferencesAsync(),
  ),
);

final remindersEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(reminderRepositoryProvider).isEnabled(),
);

final syncRemindersUseCaseProvider = Provider(
  (ref) => SyncRemindersUseCase(
    ref.watch(reminderRepositoryProvider),
    ref.watch(mealLogRepositoryProvider),
  ),
);

/// Reschedules reminders. `HomeScreen` listens to it, so it runs on launch;
/// it reruns on app resume (new day, new time zone) and whenever meals
/// change (today's logged meal types decide which reminders are skipped).
final reminderSyncProvider = FutureProvider<void>((ref) async {
  ref.watch(mealLogChangesProvider);
  final listener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(listener.dispose);
  final userId = ref.watch(authUserIdProvider).valueOrNull;
  if (userId == null) return;
  await ref.watch(syncRemindersUseCaseProvider)(userId);
});
