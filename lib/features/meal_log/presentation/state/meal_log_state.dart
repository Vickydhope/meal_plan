import '../../domain/entities/meal_log.dart';

class MealLogState {
  const MealLogState({
    this.logs = const [],
    this.selectedDate,
    this.isLoadingLogs = false,
    this.error,
  });

  final List<MealLog> logs;
  final DateTime? selectedDate;

  /// True while [logs] is being (re)fetched for [selectedDate] — the home
  /// screen shows a shimmer skeleton instead of stale/empty content while
  /// this is true.
  final bool isLoadingLogs;
  final String? error;

  int get totalCaloriesToday =>
      logs.fold(0, (sum, log) => sum + log.totalCalories);
  int get totalProteinToday =>
      logs.fold(0, (sum, log) => sum + log.totalProtein);
  int get totalCarbsToday => logs.fold(0, (sum, log) => sum + log.totalCarbs);
  int get totalFatsToday => logs.fold(0, (sum, log) => sum + log.totalFats);

  MealLogState copyWith({
    List<MealLog>? logs,
    DateTime? selectedDate,
    bool? isLoadingLogs,
    String? error,
    bool clearError = false,
  }) {
    return MealLogState(
      logs: logs ?? this.logs,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoadingLogs: isLoadingLogs ?? this.isLoadingLogs,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
