import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/fitness/domain/repositories/fitness_repository.dart';
import 'package:meal_plan/features/fitness/domain/repositories/weight_log_repository.dart';
import 'package:meal_plan/features/fitness/domain/usecases/get_weight_history_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockFitnessRepository extends Mock implements FitnessRepository {}

class _MockWeightLogRepository extends Mock implements WeightLogRepository {}

void main() {
  late _MockFitnessRepository fitness;
  late _MockWeightLogRepository weightLogs;
  late GetWeightHistoryUseCase useCase;
  final now = DateTime(2026, 9, 27, 15);
  final start = DateTime(2026, 9, 21);
  final end = DateTime(2026, 9, 28);
  final stored = [
    (kg: 81.0, measuredAt: DateTime(2026, 9, 21, 7)),
    (kg: 80.6, measuredAt: DateTime(2026, 9, 25, 7)),
    (kg: 80.2, measuredAt: DateTime(2026, 9, 25, 21)),
  ];

  setUp(() {
    fitness = _MockFitnessRepository();
    weightLogs = _MockWeightLogRepository();
    useCase = GetWeightHistoryUseCase(fitness, weightLogs);
    when(() => weightLogs.fetchWeights(userId: 'u', start: start, end: end))
        .thenAnswer((_) async => stored);
    when(() => weightLogs.importWeights(any(), any())).thenAnswer((_) async {});
  });

  test(
    'imports Health readings, then keeps the last reading per day',
    () async {
      final fromHealth = [(kg: 80.9, measuredAt: DateTime(2026, 9, 22, 7))];
      when(() => fitness.isSyncEnabled()).thenAnswer((_) async => true);
      when(() => fitness.getWeights(start: start, end: end))
          .thenAnswer((_) async => fromHealth);

      final result = await useCase(userId: 'u', days: 7, now: now);

      verify(() => weightLogs.importWeights('u', fromHealth)).called(1);
      expect(result.map((w) => w.kg), [81.0, 80.2]);
    },
  );

  test('skips the import when sync is off', () async {
    when(() => fitness.isSyncEnabled()).thenAnswer((_) async => false);

    await useCase(userId: 'u', days: 7, now: now);

    verifyNever(() => fitness.getWeights(start: start, end: end));
    verifyNever(() => weightLogs.importWeights(any(), any()));
  });

  test('still returns stored history when Health is unavailable', () async {
    when(() => fitness.isSyncEnabled()).thenAnswer((_) async => true);
    when(() => fitness.getWeights(start: start, end: end))
        .thenThrow(HealthStoreUnavailableException('nope'));

    final result = await useCase(userId: 'u', days: 7, now: now);

    expect(result, hasLength(2));
  });
}
