import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_item.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/entities/pending_meal_analysis.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/meal_log_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/relog_meal_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockMealLogRepository extends Mock implements MealLogRepository {}

MealLog _log({String? imageUrl, List<MealAnalysisItem> items = const []}) =>
    MealLog(
      id: 'old',
      userId: 'u',
      imageUrl: imageUrl,
      mealName: 'Oatmeal',
      totalCalories: 350,
      totalProtein: 12,
      totalCarbs: 60,
      totalFats: 7,
      healthScore: 8,
      createdAt: DateTime(2026, 9, 20, 8),
      mealType: MealType.breakfast,
      items: items,
    );

void main() {
  late _MockMealLogRepository repository;

  setUp(() {
    repository = _MockMealLogRepository();
    when(
      () => repository.saveMealLog(
        userId: any(named: 'userId'),
        analysis: any(named: 'analysis'),
      ),
    ).thenAnswer((_) async => _log());
  });

  setUpAll(
    () => registerFallbackValue(
      const PendingMealAnalysis(
        storagePath: null,
        mealName: '',
        healthScore: 0,
        items: [],
        mealType: MealType.snack,
      ),
    ),
  );

  PendingMealAnalysis saved() =>
      verify(
            () => repository.saveMealLog(
              userId: 'u',
              analysis: captureAny(named: 'analysis'),
            ),
          ).captured.single
          as PendingMealAnalysis;

  test('copies photo, meal type and portion-adjusted items', () async {
    const item = MealAnalysisItem(
      foodName: 'Oats',
      estimatedWeightG: 80,
      calories: 300,
      proteinG: 10,
      carbsG: 54,
      fatsG: 6,
      portion: 1.5,
    );
    await RelogMealUseCase(repository)(
      userId: 'u',
      log: _log(imageUrl: 'u/1.jpg', items: [item]),
    );

    final analysis = saved();
    expect(analysis.storagePath, 'u/1.jpg');
    expect(analysis.mealType, MealType.breakfast);
    expect(analysis.totalCalories, 450);
  });

  test('keeps a legacy log\'s totals when it has no item breakdown', () async {
    await RelogMealUseCase(repository)(userId: 'u', log: _log());

    final analysis = saved();
    expect(analysis.storagePath, isNull);
    expect(
      [
        analysis.totalCalories,
        analysis.totalProtein,
        analysis.totalCarbs,
        analysis.totalFats,
      ],
      [350, 12, 60, 7],
    );
  });
}
