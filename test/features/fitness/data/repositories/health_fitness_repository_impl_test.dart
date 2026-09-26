import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/fitness/data/repositories/health_fitness_repository_impl.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart'
    as app;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHealth extends Mock implements Health {}

class _MockPrefs extends Mock implements SharedPreferencesAsync {}

HealthDataPoint _energy(num kcal) => _point(
  HealthDataType.ACTIVE_ENERGY_BURNED,
  kcal,
  DateTime(2026, 9, 24, 12),
);

HealthDataPoint _point(HealthDataType type, num value, DateTime at) =>
    HealthDataPoint(
      uuid: '$type-$value',
      value: NumericHealthValue(numericValue: value),
      type: type,
      unit: HealthDataUnit.KILOCALORIE,
      dateFrom: at,
      dateTo: at,
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'device',
      sourceId: 'source',
      sourceName: 'source',
    );

void main() {
  late _MockHealth health;
  late _MockPrefs prefs;
  late HealthFitnessRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(DateTime(0));
    registerFallbackValue(MealType.UNKNOWN);
    registerFallbackValue(HealthDataType.NUTRITION);
  });

  setUp(() {
    health = _MockHealth();
    prefs = _MockPrefs();
    repository = HealthFitnessRepositoryImpl(health, prefs);
    when(() => health.configure()).thenAnswer((_) async {});
  });

  test('getActivityForDay reads steps and sums active energy', () async {
    when(() => health.getTotalStepsInInterval(any(), any()))
        .thenAnswer((_) async => 8123);
    when(
      () => health.getHealthIntervalDataFromTypes(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        types: any(named: 'types'),
        interval: any(named: 'interval'),
      ),
    ).thenAnswer((_) async => [_energy(200.4), _energy(120.3)]);

    final activity = await repository.getActivityForDay(DateTime(2026, 9, 1));

    expect(activity.steps, 8123);
    expect(activity.activeEnergyBurnedKcal, 321);
    expect(activity.date, DateTime(2026, 9, 1));
    // A past day is read up to its own midnight, not "now".
    verify(
      () => health.getTotalStepsInInterval(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
      ),
    ).called(1);
  });

  test('getActivityForDay wraps plugin failures', () async {
    when(() => health.getTotalStepsInInterval(any(), any()))
        .thenThrow(Exception('HealthKit error 5'));

    expect(
      () => repository.getActivityForDay(DateTime(2026, 9, 1)),
      throwsA(isA<HealthStoreUnavailableException>()),
    );
  });

  test('requestPermissions throws when the user declines', () async {
    when(() => health.requestAuthorization(any()))
        .thenAnswer((_) async => false);

    expect(
      repository.requestPermissions,
      throwsA(isA<HealthPermissionDeniedException>()),
    );
  });

  test('getLatestWeight picks the most recent reading', () async {
    when(
      () => health.getHealthDataFromTypes(
        types: any(named: 'types'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer(
      (_) async => [
        _point(HealthDataType.WEIGHT, 81, DateTime(2026, 9, 20)),
        _point(HealthDataType.WEIGHT, 79.4, DateTime(2026, 9, 23)),
        _point(HealthDataType.WEIGHT, 80, DateTime(2026, 9, 21)),
      ],
    );

    final latest = await repository.getLatestWeight();

    expect(latest?.kg, 79.4);
    expect(latest?.measuredAt, DateTime(2026, 9, 23));
  });

  test('getLatestWeight is null with no readings', () async {
    when(
      () => health.getHealthDataFromTypes(
        types: any(named: 'types'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async => []);

    expect(await repository.getLatestWeight(), isNull);
  });

  group('meal write-back', () {
    final log = MealLog(
      id: 'log-1',
      userId: 'user-1',
      imageUrl: null,
      mealName: 'Chicken Bowl',
      totalCalories: 520,
      totalProtein: 42,
      totalCarbs: 55,
      totalFats: 14,
      healthScore: 8,
      createdAt: DateTime.utc(2026, 9, 25, 12, 30),
      mealType: app.MealType.lunch,
      items: const [],
    );

    void stubWrite(bool result) => when(
      () => health.writeMeal(
        mealType: any(named: 'mealType'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        name: any(named: 'name'),
        caloriesConsumed: any(named: 'caloriesConsumed'),
        protein: any(named: 'protein'),
        carbohydrates: any(named: 'carbohydrates'),
        fatTotal: any(named: 'fatTotal'),
      ),
    ).thenAnswer((_) async => result);

    test('writeMeal sends the meal totals at its logged time', () async {
      stubWrite(true);

      await repository.writeMeal(log);

      final at = log.createdAt.toLocal();
      verify(
        () => health.writeMeal(
          mealType: MealType.LUNCH,
          startTime: at,
          endTime: at.add(const Duration(seconds: 1)),
          name: 'Chicken Bowl',
          caloriesConsumed: 520,
          protein: 42,
          carbohydrates: 55,
          fatTotal: 14,
        ),
      ).called(1);
    });

    test('writeMeal throws when the store rejects it', () async {
      stubWrite(false);

      expect(
        () => repository.writeMeal(log),
        throwsA(isA<HealthStoreUnavailableException>()),
      );
    });

    test('deleteMeal targets only a ±1s window around the meal record', () async {
      when(
        () => health.delete(
          type: any(named: 'type'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async => true);

      await repository.deleteMeal(log.createdAt);

      final at = log.createdAt.toLocal();
      verify(
        () => health.delete(
          type: HealthDataType.NUTRITION,
          startTime: at.subtract(const Duration(seconds: 1)),
          endTime: at.add(const Duration(seconds: 2)),
        ),
      ).called(1);
    });
  });

  test('sync is off until the user opts in', () async {
    when(() => prefs.getBool(any())).thenAnswer((_) async => null);

    expect(await repository.isSyncEnabled(), isFalse);
  });
}
