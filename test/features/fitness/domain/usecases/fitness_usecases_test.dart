import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/fitness/domain/entities/daily_activity.dart';
import 'package:meal_plan/features/fitness/domain/repositories/activity_log_repository.dart';
import 'package:meal_plan/features/fitness/domain/repositories/fitness_repository.dart';
import 'package:meal_plan/features/fitness/domain/usecases/calculate_activity_adjusted_target_usecase.dart';
import 'package:meal_plan/features/fitness/domain/usecases/get_today_activity_usecase.dart';
import 'package:meal_plan/features/fitness/domain/usecases/remove_meal_from_health_usecase.dart';
import 'package:meal_plan/features/fitness/domain/usecases/set_activity_sync_usecase.dart';
import 'package:meal_plan/features/fitness/domain/usecases/set_meal_write_back_usecase.dart';
import 'package:meal_plan/features/fitness/domain/usecases/sync_weight_from_health_usecase.dart';
import 'package:meal_plan/features/fitness/domain/usecases/write_meal_to_health_usecase.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart'
    as meal;
import 'package:meal_plan/features/profile/domain/entities/activity_level.dart';
import 'package:meal_plan/features/profile/domain/entities/calorie_mode.dart';
import 'package:meal_plan/features/profile/domain/entities/goal.dart';
import 'package:meal_plan/features/profile/domain/entities/sex.dart';
import 'package:meal_plan/features/profile/domain/entities/user_profile.dart';
import 'package:meal_plan/features/profile/domain/repositories/profile_repository.dart';
import 'package:meal_plan/features/profile/domain/usecases/calculate_calorie_target_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockFitnessRepository extends Mock implements FitnessRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

void main() {
  group('meal write-back', mealWriteBackTests);

  late _MockFitnessRepository repository;

  setUpAll(() {
    registerFallbackValue(DateTime(0));
    registerFallbackValue(Sex.male);
    registerFallbackValue(ActivityLevel.sedentary);
    registerFallbackValue(Goal.maintain);
    registerFallbackValue(
      DailyActivity(date: DateTime(0), steps: 0, activeEnergyBurnedKcal: 0),
    );
  });

  setUp(() {
    repository = _MockFitnessRepository();
    when(() => repository.setSyncEnabled(any())).thenAnswer((_) async {});
  });

  group('SetActivitySyncUseCase', () {
    late _MockActivityLogRepository log;
    late SetActivitySyncUseCase setSync;
    final now = DateTime(2026, 9, 25, 15);

    setUp(() {
      log = _MockActivityLogRepository();
      setSync = SetActivitySyncUseCase(repository, log, now: () => now);
      when(() => log.deleteActivity(any(), any())).thenAnswer((_) async {});
    });

    test('enabling requests permissions before saving the opt-in', () async {
      when(() => repository.requestPermissions()).thenAnswer((_) async {});

      await setSync(true, userId: 'user-1');

      verifyInOrder([
        () => repository.requestPermissions(),
        () => repository.setSyncEnabled(true),
      ]);
    });

    test('a denied permission leaves sync off', () async {
      when(() => repository.requestPermissions())
          .thenThrow(const HealthPermissionDeniedException());

      await expectLater(
        setSync(true, userId: 'user-1'),
        throwsA(isA<HealthPermissionDeniedException>()),
      );
      verifyNever(() => repository.setSyncEnabled(any()));
    });

    test('a missing health store leaves sync off', () async {
      when(() => repository.requestPermissions())
          .thenThrow(const HealthStoreUnavailableException('Install it'));

      await expectLater(
        setSync(true, userId: 'user-1'),
        throwsA(isA<HealthStoreUnavailableException>()),
      );
      verifyNever(() => repository.setSyncEnabled(any()));
    });

    test('disabling removes today\'s uploaded activity on every device, '
        'without touching permissions', () async {
      await setSync(false, userId: 'user-1');

      verify(() => log.deleteActivity('user-1', now)).called(1);
      verify(() => repository.setSyncEnabled(false)).called(1);
      verifyNever(() => repository.requestPermissions());
    });
  });

  group('GetTodayActivityUseCase', () {
    late _MockActivityLogRepository log;
    late GetTodayActivityUseCase getToday;
    final now = DateTime(2026, 9, 24, 15);
    final activity = DailyActivity(
      date: DateTime(2026, 9, 24),
      steps: 8000,
      activeEnergyBurnedKcal: 320,
    );

    setUp(() {
      log = _MockActivityLogRepository();
      getToday = GetTodayActivityUseCase(repository, log, now: () => now);
    });

    test(
      'a device without Health sync shows what another device uploaded',
      () async {
        when(() => repository.isSyncEnabled()).thenAnswer((_) async => false);
        when(() => log.fetchActivity('user-1', now))
            .thenAnswer((_) async => activity);

        expect(await getToday('user-1'), activity);
        verifyNever(() => repository.getActivityForDay(any()));
      },
    );

    test('a syncing device reads its health store and uploads it', () async {
      when(() => repository.isSyncEnabled()).thenAnswer((_) async => true);
      when(() => repository.getActivityForDay(now))
          .thenAnswer((_) async => activity);
      when(() => log.saveActivity('user-1', activity)).thenAnswer((_) async {});

      expect(await getToday('user-1'), activity);
      verify(() => log.saveActivity('user-1', activity)).called(1);
    });

    test('a failed upload still shows this device\'s reading', () async {
      when(() => repository.isSyncEnabled()).thenAnswer((_) async => true);
      when(() => repository.getActivityForDay(now))
          .thenAnswer((_) async => activity);
      when(() => log.saveActivity(any(), any()))
          .thenThrow(const MealLogPersistenceException('offline'));

      expect(await getToday('user-1'), activity);
    });
  });

  group('CalculateActivityAdjustedTargetUseCase', () {
    const calculate = CalculateCalorieTargetUseCase();
    const adjust = CalculateActivityAdjustedTargetUseCase(calculate);
    final now = DateTime.now();
    // Same shape as the real prod profile: male, 15 (DOB relative to today
    // so the age never drifts), 170.2 cm, 70 kg, moderate, gain.
    UserProfile profile(CalorieMode mode) => UserProfile(
      username: 'u',
      dailyCalorieTarget: 3125,
      sex: Sex.male,
      dateOfBirth: DateTime(now.year - 16, now.month, now.day + 7),
      heightCm: 170.2,
      weightKg: 70,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.gain,
      calorieMode: mode,
    );
    int targetAt(ActivityLevel level) => calculate(
      sex: Sex.male,
      dateOfBirth: profile(CalorieMode.fixed).dateOfBirth!,
      heightCm: 170.2,
      weightKg: 70,
      activityLevel: level,
      goal: Goal.gain,
    ).dailyCalorieTarget;
    DailyActivity burned(int kcal) =>
        DailyActivity(date: now, steps: 30, activeEnergyBurnedKcal: kcal);

    test('fixed mode ignores activity (null = use the plan target)', () {
      expect(adjust(profile(CalorieMode.fixed), burned(900)), isNull);
    });

    test('dynamic mode is the sedentary base plus measured energy — no '
        'floor at the plan target, and never on top of it', () {
      final dynamic = profile(CalorieMode.dynamic);

      expect(adjust(dynamic, burned(0)), targetAt(ActivityLevel.sedentary));
      expect(adjust(dynamic, burned(0)), lessThan(3125));
      expect(
        adjust(dynamic, burned(900)),
        targetAt(ActivityLevel.sedentary) + 900,
      );
      expect(targetAt(ActivityLevel.moderate), 3125);
    });

    test('returns null for an incomplete profile', () {
      expect(
        adjust(
          const UserProfile(
            username: 'u',
            dailyCalorieTarget: 2000,
            calorieMode: CalorieMode.dynamic,
          ),
          burned(400),
        ),
        isNull,
      );
    });
  });

  group('SyncWeightFromHealthUseCase', () {
    late _MockProfileRepository profiles;
    late SyncWeightFromHealthUseCase sync;
    final savedAt = DateTime(2026, 9, 20);

    setUp(() {
      profiles = _MockProfileRepository();
      sync = SyncWeightFromHealthUseCase(
        fitnessRepository: repository,
        profileRepository: profiles,
        calculateTarget: const CalculateCalorieTargetUseCase(),
      );
      when(() => repository.isSyncEnabled()).thenAnswer((_) async => true);
      when(() => profiles.fetchProfile('user-1'))
          .thenAnswer((_) async => _profile(savedAt: savedAt));
      when(
        () => profiles.completeOnboarding(
          userId: any(named: 'userId'),
          sex: any(named: 'sex'),
          dateOfBirth: any(named: 'dateOfBirth'),
          heightCm: any(named: 'heightCm'),
          weightKg: any(named: 'weightKg'),
          activityLevel: any(named: 'activityLevel'),
          goal: any(named: 'goal'),
          dailyCalorieTarget: any(named: 'dailyCalorieTarget'),
        ),
      ).thenAnswer((_) async {});
    });

    void stubWeight(double kg, DateTime measuredAt) =>
        when(() => repository.getLatestWeight())
            .thenAnswer((_) async => (kg: kg, measuredAt: measuredAt));

    test('saves a newer reading and recomputes the target from it', () async {
      stubWeight(76.5, DateTime(2026, 9, 24));

      expect(await sync('user-1'), 76.5);

      final expectedTarget = const CalculateCalorieTargetUseCase()(
        sex: Sex.male,
        dateOfBirth: DateTime(1996, 1, 1),
        heightCm: 180,
        weightKg: 76.5,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.lose,
      ).dailyCalorieTarget;
      verify(
        () => profiles.completeOnboarding(
          userId: 'user-1',
          sex: Sex.male,
          dateOfBirth: DateTime(1996, 1, 1),
          heightCm: 180,
          weightKg: 76.5,
          activityLevel: ActivityLevel.moderate,
          goal: Goal.lose,
          dailyCalorieTarget: expectedTarget,
        ),
      ).called(1);
    });

    test('ignores a reading older than the last plan save', () async {
      stubWeight(76.5, DateTime(2026, 9, 19));

      expect(await sync('user-1'), isNull);
      verifyNever(
        () => profiles.completeOnboarding(
          userId: any(named: 'userId'),
          sex: any(named: 'sex'),
          dateOfBirth: any(named: 'dateOfBirth'),
          heightCm: any(named: 'heightCm'),
          weightKg: any(named: 'weightKg'),
          activityLevel: any(named: 'activityLevel'),
          goal: any(named: 'goal'),
          dailyCalorieTarget: any(named: 'dailyCalorieTarget'),
        ),
      );
    });

    test('ignores a reading equal to the saved weight', () async {
      stubWeight(80.02, DateTime(2026, 9, 24));

      expect(await sync('user-1'), isNull);
    });

    test('does nothing when sync is off', () async {
      when(() => repository.isSyncEnabled()).thenAnswer((_) async => false);

      expect(await sync('user-1'), isNull);
      verifyNever(() => repository.getLatestWeight());
    });
  });
}

class _MockProfileRepository extends Mock implements ProfileRepository {}

UserProfile _profile({
  ActivityLevel activityLevel = ActivityLevel.moderate,
  DateTime? savedAt,
}) => UserProfile(
  username: 'u',
  dailyCalorieTarget: 2000,
  sex: Sex.male,
  dateOfBirth: DateTime(1996, 1, 1),
  heightCm: 180,
  weightKg: 80,
  activityLevel: activityLevel,
  goal: Goal.lose,
  onboardingCompletedAt: savedAt,
);

MealLog _meal() => MealLog(
  id: 'log-1',
  userId: 'user-1',
  imageUrl: null,
  mealName: 'Bowl',
  totalCalories: 500,
  totalProtein: 30,
  totalCarbs: 60,
  totalFats: 15,
  healthScore: 7,
  createdAt: DateTime.utc(2026, 9, 25, 12),
  mealType: meal.MealType.lunch,
  items: const [],
);

void mealWriteBackTests() {
  late _MockFitnessRepository repository;

  setUpAll(() => registerFallbackValue(_meal()));

  setUp(() {
    repository = _MockFitnessRepository();
    when(() => repository.deleteMeal(any())).thenAnswer((_) async {});
    when(() => repository.writeMeal(any())).thenAnswer((_) async {});
    when(() => repository.setMealWriteBackEnabled(any()))
        .thenAnswer((_) async {});
  });

  test('WriteMealToHealth replaces any existing record when enabled', () async {
    when(() => repository.isMealWriteBackEnabled())
        .thenAnswer((_) async => true);
    final log = _meal();

    await WriteMealToHealthUseCase(repository)(log);

    verifyInOrder([
      () => repository.deleteMeal(log.createdAt),
      () => repository.writeMeal(log),
    ]);
  });

  test('WriteMealToHealth does nothing when disabled', () async {
    when(() => repository.isMealWriteBackEnabled())
        .thenAnswer((_) async => false);

    await WriteMealToHealthUseCase(repository)(_meal());

    verifyNever(() => repository.writeMeal(any()));
    verifyNever(() => repository.deleteMeal(any()));
  });

  test('RemoveMealFromHealth deletes by the meal timestamp', () async {
    when(() => repository.isMealWriteBackEnabled())
        .thenAnswer((_) async => true);
    final log = _meal();

    await RemoveMealFromHealthUseCase(repository)(log);

    verify(() => repository.deleteMeal(log.createdAt)).called(1);
  });

  test('SetMealWriteBack leaves it off when write access is denied', () async {
    when(() => repository.requestMealWritePermissions())
        .thenThrow(const HealthPermissionDeniedException('no'));

    await expectLater(
      SetMealWriteBackUseCase(repository)(true),
      throwsA(isA<HealthPermissionDeniedException>()),
    );
    verifyNever(() => repository.setMealWriteBackEnabled(any()));
  });
}
