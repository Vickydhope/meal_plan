import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/meal_log_repository.dart';
import 'package:meal_plan/features/notifications/domain/entities/reminder.dart';
import 'package:meal_plan/features/notifications/domain/repositories/reminder_repository.dart';
import 'package:meal_plan/features/notifications/domain/usecases/sync_reminders_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockReminderRepository extends Mock implements ReminderRepository {}

class _MockMealLogRepository extends Mock implements MealLogRepository {}

MealLog _log(MealType type) => MealLog(
  id: type.name,
  userId: 'u',
  imageUrl: null,
  mealName: type.label,
  totalCalories: 0,
  totalProtein: 0,
  totalCarbs: 0,
  totalFats: 0,
  healthScore: 0,
  createdAt: DateTime(2026, 9, 28),
  mealType: type,
  items: const [],
);

void main() {
  // A Monday, before lunch.
  final now = DateTime(2026, 9, 28, 10);

  late _MockReminderRepository reminders;
  late _MockMealLogRepository mealLogs;
  late SyncRemindersUseCase useCase;

  setUp(() {
    reminders = _MockReminderRepository();
    mealLogs = _MockMealLogRepository();
    useCase = SyncRemindersUseCase(reminders, mealLogs);
    when(() => reminders.schedule(any())).thenAnswer((_) async {});
  });

  List<Reminder> scheduled() =>
      verify(() => reminders.schedule(captureAny())).captured.single
          as List<Reminder>;

  test('does nothing while reminders are off', () async {
    when(() => reminders.isEnabled()).thenAnswer((_) async => false);
    await useCase('u', now: now);
    verifyNever(() => reminders.schedule(any()));
    verifyNever(
      () => mealLogs.fetchLogsForDate(userId: any(named: 'userId'), date: any(named: 'date')),
    );
  });

  test('skips today\'s logged lunch and past times, keeps the rest', () async {
    when(() => reminders.isEnabled()).thenAnswer((_) async => true);
    when(
      () => mealLogs.fetchLogsForDate(userId: 'u', date: now),
    ).thenAnswer((_) async => [_log(MealType.lunch)]);

    await useCase('u', now: now);
    final list = scheduled();

    // Today: 09:00 weigh-in already passed, lunch logged → only dinner.
    final today = list.where((r) => r.at.day == 28).map((r) => r.title);
    expect(today, ['Log your dinner']);
    // Next 7 days: lunch + dinner each, plus next Monday's weigh-in.
    expect(list.length, 1 + 7 * 2 + 1);
    expect(
      list.where((r) => r.title == 'Time to weigh in').single.at,
      DateTime(2026, 10, 5, 9),
    );
    expect(list.map((r) => r.id).toSet().length, list.length);
  });
}
