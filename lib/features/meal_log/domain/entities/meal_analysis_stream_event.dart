import 'meal_analysis_item.dart';
import 'pending_meal_analysis.dart';

/// One event in the live, streamed nutrition-analysis of a captured photo.
///
/// [FoodAnalysisRepository.analyze] emits [MealNameDetected]/[ItemDetected]
/// as they arrive, then a terminal [AnalysisCompleted] (with the full
/// result, as a fallback/source of truth) or [AnalysisFailed].
/// [AnalyzeMealPhotoUseCase.call] re-emits the same progress events, but
/// swaps the terminal [AnalysisCompleted] for a [PendingAnalysisReady] once
/// it pairs the result with the uploaded photo's storage path and a
/// resolved meal type — that's the only terminal event callers above the
/// use case should expect.
sealed class MealAnalysisStreamEvent {
  const MealAnalysisStreamEvent();
}

/// Emitted by [AnalyzeMealPhotoUseCase.call] as soon as the photo has been
/// uploaded, before any analysis events arrive — lets callers stop the
/// stream early (see [ScanSessionNotifier.stopAnalyzing]) while still knowing
/// where the photo landed.
class UploadCompleted extends MealAnalysisStreamEvent {
  const UploadCompleted(this.storagePath);
  final String storagePath;
}

class MealNameDetected extends MealAnalysisStreamEvent {
  const MealNameDetected(this.mealName);
  final String mealName;
}

class ItemDetected extends MealAnalysisStreamEvent {
  const ItemDetected(this.item);
  final MealAnalysisItem item;
}

class AnalysisCompleted extends MealAnalysisStreamEvent {
  const AnalysisCompleted(this.result);
  final MealAnalysisResult result;
}

class AnalysisFailed extends MealAnalysisStreamEvent {
  const AnalysisFailed(this.message);
  final String message;
}

class PendingAnalysisReady extends MealAnalysisStreamEvent {
  const PendingAnalysisReady(this.pending);
  final PendingMealAnalysis pending;
}
