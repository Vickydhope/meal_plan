import '../../../meal_log/domain/entities/meal_type.dart';

/// A one-off on-device reminder. [at] is local wall-clock time.
class Reminder {
  const Reminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
}

/// Lunch (13:00) and dinner (20:00) every day plus a Monday 09:00 weigh-in,
/// from [now] through the same weekday next week. Today's lunch/dinner is
/// skipped once a meal of that type is in [loggedToday].
///
/// One-offs rather than repeating reminders so a single day can be skipped
/// and each reschedule picks up the current time zone; the app reschedules
/// on launch/resume, so they run out only if it isn't opened for 8 days.
List<Reminder> upcomingReminders(
  DateTime now, {
  required Set<MealType> loggedToday,
}) {
  final reminders = <Reminder>[];
  for (var day = 0; day <= 7; day++) {
    void add(int slot, int hour, String title, String body) {
      final at = DateTime(now.year, now.month, now.day + day, hour);
      if (at.isAfter(now)) {
        reminders.add(
          Reminder(id: day * 10 + slot, at: at, title: title, body: body),
        );
      }
    }

    if (day > 0 || !loggedToday.contains(MealType.lunch)) {
      add(1, 13, 'Log your lunch', 'Snap a photo to keep today on track.');
    }
    if (day > 0 || !loggedToday.contains(MealType.dinner)) {
      add(
        2,
        20,
        'Log your dinner',
        "Don't forget to log your last meal of the day.",
      );
    }
    if (DateTime(now.year, now.month, now.day + day).weekday ==
        DateTime.monday) {
      add(
        3,
        9,
        'Time to weigh in',
        'Weekly check-ins help keep your calorie target accurate.',
      );
    }
  }
  return reminders;
}
