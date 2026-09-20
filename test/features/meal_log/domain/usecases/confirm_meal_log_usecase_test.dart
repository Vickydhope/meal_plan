import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_item.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/entities/pending_meal_analysis.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/meal_log_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/confirm_meal_log_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockMealLogRepository extends Mock implements MealLogRepository {}

void main() {
  late _MockMealLogRepository repository;
  late ConfirmMealLogUseCase useCase;

  setUp(() {
    repository = _MockMealLogRepository();
    useCase = ConfirmMealLogUseCase(repository);
  });

  test('saves the pending analysis for the given user and returns the '
      'persisted meal log', () async {
    const analysis = PendingMealAnalysis(
      storagePath: 'user-1/1.jpg',
      mealName: 'Grilled Chicken Bowl',
      healthScore: 8,
      mealType: MealType.lunch,
      items: [
        MealAnalysisItem(
          foodName: 'Chicken',
          estimatedWeightG: 150,
          calories: 250,
          proteinG: 40,
          carbsG: 0,
          fatsG: 8,
          portion: 1.5,
        ),
      ],
    );
    final saved = MealLog(
      id: 'log-1',
      userId: 'user-1',
      imageUrl: 'user-1/1.jpg',
      mealName: 'Grilled Chicken Bowl',
      totalCalories: 375,
      totalProtein: 60,
      totalCarbs: 0,
      totalFats: 12,
      healthScore: 8,
      createdAt: DateTime(2026, 9, 18),
      mealType: MealType.lunch,
      items: const [],
    );
    when(() => repository.saveMealLog(userId: 'user-1', analysis: analysis))
        .thenAnswer((_) async => saved);

    final result = await useCase(userId: 'user-1', analysis: analysis);

    expect(result, saved);
  });
}
