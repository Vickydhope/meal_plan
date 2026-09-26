import '../../../../core/error/app_exception.dart';
import '../entities/meal_analysis_stream_event.dart';
import '../entities/meal_type.dart';
import '../entities/pending_meal_analysis.dart';
import '../repositories/product_repository.dart';

/// Looks up a scanned barcode and emits the same events as a photo
/// analysis, ending in a [PendingAnalysisReady] (no photo) or
/// [AnalysisFailed] — so the review screen handles it like any other scan.
class LookUpBarcodeUseCase {
  LookUpBarcodeUseCase(this._repository);

  final ProductRepository _repository;

  Stream<MealAnalysisStreamEvent> call({
    required String barcode,
    MealType? mealType,
  }) async* {
    final MealAnalysisResult? result;
    try {
      result = await _repository.findByBarcode(barcode);
    } catch (err) {
      yield AnalysisFailed(userMessageFor(err));
      return;
    }
    if (result == null) {
      yield const AnalysisFailed(
        "We couldn't find this product. Try taking a photo of it instead.",
      );
      return;
    }
    yield MealNameDetected(result.mealName);
    yield PendingAnalysisReady(
      PendingMealAnalysis(
        storagePath: null,
        mealName: result.mealName,
        healthScore: result.healthScore,
        items: result.items,
        mealType: mealType ?? MealType.forTime(DateTime.now()),
      ),
    );
  }
}
