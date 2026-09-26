import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_item.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_stream_event.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/entities/pending_meal_analysis.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/product_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/look_up_barcode_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late _MockProductRepository repository;
  late LookUpBarcodeUseCase useCase;

  setUp(() {
    repository = _MockProductRepository();
    useCase = LookUpBarcodeUseCase(repository);
  });

  test('a found product becomes a pending meal with no photo', () async {
    const item = MealAnalysisItem(
      foodName: 'Nutella (Nutella)',
      estimatedWeightG: 100,
      calories: 539,
      proteinG: 6.3,
      carbsG: 57.5,
      fatsG: 30.9,
    );
    when(() => repository.findByBarcode('3017620422003')).thenAnswer(
      (_) async => const MealAnalysisResult(
        mealName: 'Nutella',
        healthScore: 2,
        items: [item],
      ),
    );

    final events = await useCase(
      barcode: '3017620422003',
      mealType: MealType.snack,
    ).toList();

    expect((events.first as MealNameDetected).mealName, 'Nutella');
    final pending = (events.last as PendingAnalysisReady).pending;
    expect(pending.storagePath, isNull);
    expect(pending.mealType, MealType.snack);
    expect(pending.totalCalories, 539);
  });

  test('an unknown product fails with a helpful message', () async {
    when(() => repository.findByBarcode(any())).thenAnswer((_) async => null);

    final events = await useCase(barcode: '12345678').toList();

    expect(
      (events.single as AnalysisFailed).message,
      contains("couldn't find this product"),
    );
  });

  test('a lookup error surfaces its user-facing message', () async {
    when(() => repository.findByBarcode(any()))
        .thenThrow(const FoodAnalysisException('No nutrition facts.'));

    final events = await useCase(barcode: '12345678').toList();

    expect((events.single as AnalysisFailed).message, 'No nutrition facts.');
  });
}
