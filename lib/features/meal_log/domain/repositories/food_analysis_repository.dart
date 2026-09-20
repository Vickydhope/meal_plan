import 'dart:typed_data';

import '../entities/meal_analysis_stream_event.dart';

abstract class FoodAnalysisRepository {
  /// Sends [imageBytes] off for nutrition analysis, streaming
  /// [MealNameDetected]/[ItemDetected] events as Gemini detects them,
  /// followed by a terminal [AnalysisCompleted] or [AnalysisFailed].
  Stream<MealAnalysisStreamEvent> analyze({
    required Uint8List imageBytes,
    required String mimeType,
  });
}
