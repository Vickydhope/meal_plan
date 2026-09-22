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

  /// Aborts the in-flight [analyze] request, if any, so a subscription
  /// cancellation takes effect immediately instead of waiting for the
  /// network call it's suspended on to finish on its own — cancelling a
  /// [Stream] subscription only stops a generator at its next await/yield,
  /// which for a single in-flight HTTP call can be many seconds away.
  void cancelInFlight();
}
