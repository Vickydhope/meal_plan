import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/meal_log_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/fetch_meal_logs_page_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockMealLogRepository extends Mock implements MealLogRepository {}

MealLog _log(String id, DateTime createdAt) => MealLog(
      id: id,
      userId: 'user-1',
      imageUrl: null,
      mealName: 'Meal $id',
      totalCalories: 300,
      totalProtein: 10,
      totalCarbs: 20,
      totalFats: 5,
      healthScore: 9,
      createdAt: createdAt,
      mealType: MealType.lunch,
      items: const [],
    );

void main() {
  late _MockMealLogRepository repository;
  late FetchMealLogsPageUseCase useCase;

  setUp(() {
    repository = _MockMealLogRepository();
    useCase = FetchMealLogsPageUseCase(repository);
  });

  test('fetches the first page with the default limit and no cursor',
      () async {
    final expected = [_log('1', DateTime(2026, 9, 18))];
    when(
      () => repository.fetchLogsPage(
        userId: 'user-1',
        before: null,
        limit: 20,
      ),
    ).thenAnswer((_) async => expected);

    final result = await useCase(userId: 'user-1');

    expect(result, expected);
    verify(
      () => repository.fetchLogsPage(
        userId: 'user-1',
        before: null,
        limit: 20,
      ),
    ).called(1);
  });

  test('forwards a cursor and custom limit to the repository', () async {
    final cursor = DateTime(2026, 9, 10);
    final expected = [_log('2', DateTime(2026, 9, 9))];
    when(
      () => repository.fetchLogsPage(
        userId: 'user-1',
        before: cursor,
        limit: 5,
      ),
    ).thenAnswer((_) async => expected);

    final result = await useCase(userId: 'user-1', before: cursor, limit: 5);

    expect(result, expected);
    verify(
      () => repository.fetchLogsPage(
        userId: 'user-1',
        before: cursor,
        limit: 5,
      ),
    ).called(1);
  });
}
