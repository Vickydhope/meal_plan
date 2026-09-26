import 'dart:io';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/app_exception.dart';
import '../../../meal_log/domain/entities/meal_log.dart';
import '../../../meal_log/domain/entities/meal_type.dart' as app;
import '../../domain/entities/daily_activity.dart';
import '../../domain/repositories/fitness_repository.dart';

class HealthFitnessRepositoryImpl implements FitnessRepository {
  HealthFitnessRepositoryImpl(this._health, this._prefs);

  final Health _health;
  final SharedPreferencesAsync _prefs;
  Future<void>? _configured;

  static const _syncEnabledKey = 'fitness.sync_enabled';
  static const _mealWriteBackKey = 'fitness.meal_write_back';
  static const _mealDuration = Duration(seconds: 1);
  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WEIGHT,
  ];

  Future<void> _ready() => _configured ??= _health.configure();

  Future<void> _ensureStoreInstalled() async {
    await _ready();
    if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
      // Opens the Play Store listing — the package's recommended prompt.
      await _health.installHealthConnect();
      throw const HealthStoreUnavailableException(
        'Install Health Connect, then turn this on again.',
      );
    }
  }

  @override
  Future<void> requestPermissions() async {
    await _ensureStoreInstalled();
    final granted = await _health.requestAuthorization(_types);
    if (!granted) throw const HealthPermissionDeniedException();
  }

  @override
  Future<void> requestMealWritePermissions() async {
    await _ensureStoreInstalled();
    final granted = await _health.requestAuthorization(
      const [HealthDataType.NUTRITION, HealthDataType.WATER],
      permissions: const [HealthDataAccess.WRITE, HealthDataAccess.WRITE],
    );
    if (!granted) {
      throw const HealthPermissionDeniedException(
        'Allow writing nutrition and water data to save them to Health.',
      );
    }
  }

  @override
  Future<void> writeWater(DateTime day, int ml) async {
    await _ready();
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final now = DateTime.now();
    // One record spanning the day so far; Health Connect needs its end
    // after its start.
    final recordEnd = now.isAfter(start) && now.isBefore(end)
        ? now
        : end.subtract(const Duration(seconds: 1));
    try {
      // Anyone who turned write-back on before water existed never granted
      // it, so ask here (a no-op sheet-wise once granted).
      final canWrite = await _health.hasPermissions(
        const [HealthDataType.WATER],
        permissions: const [HealthDataAccess.WRITE],
      );
      if (canWrite != true &&
          !await _health.requestAuthorization(
            const [HealthDataType.WATER],
            permissions: const [HealthDataAccess.WRITE],
          )) {
        throw const HealthPermissionDeniedException(
          'Allow writing water data to save water to Health.',
        );
      }
      // Both stores only delete this app's own records, so this replaces
      // our previous total for the day without touching other apps' water.
      await _health.delete(
        type: HealthDataType.WATER,
        startTime: start,
        endTime: end,
      );
      if (ml == 0) return;
      final ok = await _health.writeHealthData(
        value: ml / 1000,
        unit: HealthDataUnit.LITER,
        type: HealthDataType.WATER,
        startTime: start,
        endTime: recordEnd,
      );
      if (!ok) throw Exception('write returned false');
    } on AppException {
      rethrow;
    } catch (_) {
      throw HealthStoreUnavailableException(
        "Couldn't save water to $_storeName.",
      );
    }
  }

  @override
  Future<void> writeMeal(MealLog log) async {
    await _ready();
    final at = log.createdAt.toLocal();
    final ok = await _health.writeMeal(
      mealType: switch (log.mealType) {
        app.MealType.breakfast => MealType.BREAKFAST,
        app.MealType.lunch => MealType.LUNCH,
        app.MealType.dinner => MealType.DINNER,
        app.MealType.snack => MealType.SNACK,
      },
      startTime: at,
      // Health Connect rejects a NutritionRecord whose end isn't after its
      // start, so give the meal a nominal duration.
      endTime: at.add(_mealDuration),
      name: log.mealName,
      caloriesConsumed: log.totalCalories.toDouble(),
      protein: log.totalProtein.toDouble(),
      carbohydrates: log.totalCarbs.toDouble(),
      fatTotal: log.totalFats.toDouble(),
    );
    if (!ok) {
      throw HealthStoreUnavailableException(
        "Couldn't save meal to $_storeName.",
      );
    }
  }

  @override
  Future<void> deleteMeal(DateTime loggedAt) async {
    await _ready();
    // Neither platform lets a portable id round-trip (iOS ignores
    // clientRecordId), so a meal's record is found by its exact timestamp.
    // Both stores only delete this app's own records, so the ±1s window
    // can't touch other apps' data.
    final at = loggedAt.toLocal();
    final types = [
      HealthDataType.NUTRITION,
      // iOS stores a meal as a food correlation plus per-nutrient samples;
      // delete the samples too so Apple Health's daily totals drop.
      if (Platform.isIOS) ...const [
        HealthDataType.DIETARY_ENERGY_CONSUMED,
        HealthDataType.DIETARY_PROTEIN_CONSUMED,
        HealthDataType.DIETARY_CARBS_CONSUMED,
        HealthDataType.DIETARY_FATS_CONSUMED,
      ],
    ];
    for (final type in types) {
      await _health.delete(
        type: type,
        startTime: at.subtract(const Duration(seconds: 1)),
        endTime: at.add(_mealDuration + const Duration(seconds: 1)),
      );
    }
  }

  @override
  Future<bool> isMealWriteBackEnabled() async =>
      await _prefs.getBool(_mealWriteBackKey) ?? false;

  @override
  Future<void> setMealWriteBackEnabled(bool enabled) =>
      _prefs.setBool(_mealWriteBackKey, enabled);

  String get _storeName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  Future<DailyActivity> getActivityForDay(DateTime day) async {
    await _ready();
    final start = DateTime(day.year, day.month, day.day);
    final now = DateTime.now();
    final nextDay = start.add(const Duration(days: 1));
    final end = now.isBefore(nextDay) ? now : nextDay;

    try {
      final steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
      // Interval (statistics) queries sum across sources the way the OS's
      // own Health app does, so a watch and phone both recording active
      // energy aren't double-counted — unlike summing raw samples.
      final energy = await _health.getHealthIntervalDataFromTypes(
        startDate: start,
        endDate: end,
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
        interval: end.difference(start).inSeconds.clamp(1, 86400),
      );
      final kcal = energy.fold<num>(
        0,
        (sum, point) => switch (point.value) {
          NumericHealthValue(:final numericValue) => sum + numericValue,
          _ => sum,
        },
      );
      return DailyActivity(
        date: start,
        steps: steps,
        activeEnergyBurnedKcal: kcal.round(),
      );
    } on AppException {
      rethrow;
    } catch (err) {
      throw HealthStoreUnavailableException(
        "Couldn't read activity from $_storeName.",
      );
    }
  }

  @override
  Future<({double kg, DateTime measuredAt})?> getLatestWeight() async {
    final now = DateTime.now();
    final weights = await getWeights(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    return weights.isEmpty
        ? null
        : weights.reduce((a, b) => b.measuredAt.isAfter(a.measuredAt) ? b : a);
  }

  @override
  Future<List<({double kg, DateTime measuredAt})>> getWeights({
    required DateTime start,
    required DateTime end,
  }) async {
    await _ready();
    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WEIGHT],
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      throw HealthStoreUnavailableException(
        "Couldn't read weight from $_storeName.",
      );
    }
    return [
      for (final point in points)
        if (point.value case NumericHealthValue(:final numericValue))
          // WEIGHT is always reported in kilograms by the plugin.
          (kg: numericValue.toDouble(), measuredAt: point.dateTo),
    ];
  }

  @override
  Future<bool> isSyncEnabled() async =>
      await _prefs.getBool(_syncEnabledKey) ?? false;

  @override
  Future<void> setSyncEnabled(bool enabled) =>
      _prefs.setBool(_syncEnabledKey, enabled);
}
