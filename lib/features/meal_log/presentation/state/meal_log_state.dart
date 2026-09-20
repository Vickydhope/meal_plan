import '../../domain/entities/meal_analysis_item.dart';
import '../../domain/entities/meal_log.dart';
import '../../domain/entities/pending_meal_analysis.dart';

class MealLogState {
  const MealLogState({
    this.logs = const [],
    this.dailyTarget = 2000,
    this.username,
    this.avatarPath,
    this.selectedDate,
    this.isProcessing = false,
    this.pendingAnalysis,
    this.error,
    this.isStreaming = false,
    this.streamingMealName,
    this.streamingItems = const [],
  });

  final List<MealLog> logs;
  final int dailyTarget;
  final String? username;

  /// Storage path within the public `avatars` bucket — resolve to a
  /// displayable URL via `AvatarRepository.publicUrlFor`.
  final String? avatarPath;
  final DateTime? selectedDate;
  final bool isProcessing;
  final PendingMealAnalysis? pendingAnalysis;
  final String? error;

  /// Live progress of an in-flight, streamed photo analysis — see
  /// [MealLogNotifier.analyzeCapturedPhoto].
  final bool isStreaming;
  final String? streamingMealName;
  final List<MealAnalysisItem> streamingItems;

  int get totalCaloriesToday =>
      logs.fold(0, (sum, log) => sum + log.totalCalories);
  int get totalProteinToday =>
      logs.fold(0, (sum, log) => sum + log.totalProtein);
  int get totalCarbsToday => logs.fold(0, (sum, log) => sum + log.totalCarbs);
  int get totalFatsToday => logs.fold(0, (sum, log) => sum + log.totalFats);

  MealLogState copyWith({
    List<MealLog>? logs,
    int? dailyTarget,
    String? username,
    String? avatarPath,
    DateTime? selectedDate,
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
    return MealLogState(
      logs: logs ?? this.logs,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      username: username ?? this.username,
      avatarPath: avatarPath ?? this.avatarPath,
      selectedDate: selectedDate ?? this.selectedDate,
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
