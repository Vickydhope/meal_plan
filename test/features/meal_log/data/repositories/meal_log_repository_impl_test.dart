import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/meal_log/data/datasources/meal_log_remote_data_source.dart';
import 'package:meal_plan/features/meal_log/data/repositories/meal_log_repository_impl.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_item.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements MealLogRemoteDataSource {}

void main() {
  late _MockDataSource dataSource;
  late MealLogRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    dataSource = _MockDataSource();
    repository = MealLogRepositoryImpl(dataSource);
  });

  Map<String, dynamic> row(String id) => {
    'id': id,
    'user_id': 'user-1',
    'created_at': '2026-09-24T08:00:00Z',
    'meal_type': 'lunch',
  };

  test(
    'fetchLogsForDate queries local midnight to next local midnight',
    () async {
      when(
        () => dataSource.fetchLogsForRange(
          userId: 'user-1',
          start: DateTime(2026, 9, 24),
          end: DateTime(2026, 9, 25),
        ),
      ).thenAnswer((_) async => [row('log-1')]);

      final logs = await repository.fetchLogsForDate(
        userId: 'user-1',
        date: DateTime(2026, 9, 24, 18, 30),
      );

      expect(logs.single.id, 'log-1');
      expect(logs.single.mealType, MealType.lunch);
    },
  );

  test('updateMealLog derives stored totals from portion-adjusted items, '
      'ignoring the stale totals on the entity', () async {
    when(() => dataSource.updateMealLog(any(), any()))
        .thenAnswer((_) async => row('log-1'));
    final log = MealLog(
      id: 'log-1',
      userId: 'user-1',
      imageUrl: null,
      mealName: 'Bowl',
      totalCalories: 9999,
      totalProtein: 9999,
      totalCarbs: 9999,
      totalFats: 9999,
      healthScore: 5,
      createdAt: DateTime(2026, 9, 24),
      mealType: MealType.lunch,
      items: const [
        MealAnalysisItem(
          foodName: 'Chicken',
          estimatedWeightG: 100,
          calories: 200,
          proteinG: 30,
          carbsG: 0,
          fatsG: 8,
          portion: 1.5,
        ),
        MealAnalysisItem(
          foodName: 'Rice',
          estimatedWeightG: 100,
          calories: 130,
          proteinG: 3,
          carbsG: 28,
          fatsG: 0,
        ),
      ],
    );

    await repository.updateMealLog(log);

    final payload =
        verify(() => dataSource.updateMealLog('log-1', captureAny()))
                .captured
                .single
            as Map<String, dynamic>;
    expect(payload['total_calories'], 430); // 200*1.5 + 130
    expect(payload['total_protein'], 48); // 30*1.5 + 3
    expect(payload['total_carbs'], 28);
    expect(payload['total_fats'], 12); // 8*1.5
    expect((payload['raw_json_data'] as Map)['items'], hasLength(2));
  });

  test('wraps data-source failures in MealLogPersistenceException', () async {
    when(() => dataSource.deleteMealLog('log-1')).thenThrow(Exception('boom'));

    expect(
      () => repository.deleteMealLog('log-1'),
      throwsA(isA<MealLogPersistenceException>()),
    );
  });
}
