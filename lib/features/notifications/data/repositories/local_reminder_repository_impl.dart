import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';

class LocalReminderRepositoryImpl implements ReminderRepository {
  LocalReminderRepositoryImpl(this._plugin, this._prefs);

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferencesAsync _prefs;
  Future<void>? _initialized;

  static const _enabledKey = 'notifications.reminders_enabled';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Meal logging and weigh-in reminders',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _ready() => _initialized ??= () async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  @override
  Future<bool> isEnabled() async => await _prefs.getBool(_enabledKey) ?? false;

  @override
  Future<void> setEnabled(bool enabled) async {
    await _ready();
    if (enabled) {
      await _requestPermission();
    } else {
      await _plugin.cancelAll();
    }
    await _prefs.setBool(_enabledKey, enabled);
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    await _ready();
    // Re-read every time so a zone change (travel) moves the reminders.
    final zone = await FlutterTimezone.getLocalTimezone();
    final local = tz.getLocation(zone.identifier);
    await _plugin.cancelAll();
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime(
          local,
          r.at.year,
          r.at.month,
          r.at.day,
          r.at.hour,
          r.at.minute,
        ),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
      );
    }
  }

  Future<void> _requestPermission() async {
    final granted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
    if (!granted) throw const NotificationPermissionDeniedException();
  }
}
