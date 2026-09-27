import '../../domain/entities/meal_analysis_item.dart';
import '../../domain/entities/pending_meal_analysis.dart';

/// One scan → review → confirm session on `ScanResultScreen`.
class ScanSessionState {
  const ScanSessionState({
    this.isProcessing = false,
    this.pendingAnalysis,
    this.error,
    this.isStreaming = false,
    this.streamingMealName,
    this.streamingItems = const [],
  });

  final bool isProcessing;
  final PendingMealAnalysis? pendingAnalysis;
  final String? error;

  /// Live progress of an in-flight, streamed analysis — see
  /// [ScanSessionNotifier.analyzeCapturedPhoto].
  final bool isStreaming;
  final String? streamingMealName;
  final List<MealAnalysisItem> streamingItems;

  ScanSessionState copyWith({
    bool? isProcessing,
    PendingMealAnalysis? pendingAnalysis,
    bool clearPendingAnalysis = false,
    String? error,
    bool clearError = false,
    bool? isStreaming,
    String? streamingMealName,
    List<MealAnalysisItem>? streamingItems,
    bool clearStreamingProgress = false,
  }) {
    return ScanSessionState(
      isProcessing: isProcessing ?? this.isProcessing,
      pendingAnalysis: clearPendingAnalysis
          ? null
          : (pendingAnalysis ?? this.pendingAnalysis),
      error: clearError ? null : (error ?? this.error),
      isStreaming: isStreaming ?? this.isStreaming,
      streamingMealName: clearStreamingProgress
          ? null
          : (streamingMealName ?? this.streamingMealName),
      streamingItems: clearStreamingProgress
          ? const []
          : (streamingItems ?? this.streamingItems),
    );
  }
}
