import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/meal_log_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/fetch_meal_logs_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockMealLogRepository extends Mock implements MealLogRepository {}

void main() {
  late _MockMealLogRepository repository;
  late FetchMealLogsUseCase useCase;

  setUp(() {
    repository = _MockMealLogRepository();
    useCase = FetchMealLogsUseCase(repository);
  });

  test('delegates to the repository with the given user and date', () async {
    final date = DateTime(2026, 9, 18);
    final expected = [
      MealLog(
        id: '1',
        userId: 'user-1',
        imageUrl: null,
        mealName: 'Salad',
        totalCalories: 300,
        totalProtein: 10,
        totalCarbs: 20,
        totalFats: 5,
        healthScore: 9,
        createdAt: date,
        mealType: MealType.lunch,
        items: const [],
      ),
    ];
    when(() => repository.fetchLogsForDate(userId: 'user-1', date: date))
        .thenAnswer((_) async => expected);

    final result = await useCase(userId: 'user-1', date: date);

    expect(result, expected);
    verify(() => repository.fetchLogsForDate(userId: 'user-1', date: date))
        .called(1);
  });
}
