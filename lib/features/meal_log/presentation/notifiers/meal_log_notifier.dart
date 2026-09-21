import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/meal_analysis_item.dart';
import '../../domain/entities/meal_analysis_stream_event.dart';
import '../../domain/entities/meal_log.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/pending_meal_analysis.dart';
import '../providers/meal_log_providers.dart';
import '../state/meal_log_state.dart';

/// Presentation-layer orchestrator. Pulls its dependencies (use cases,
/// [AuthRepository]) from providers rather than talking to Supabase or any
/// other infra package directly — everything it does goes through the
/// domain layer.
class MealLogNotifier extends Notifier<MealLogState> {
  StreamSubscription<MealAnalysisStreamEvent>? _analysisSub;
  String? _streamingStoragePath;

  @override
  MealLogState build() {
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    Future.microtask(_loadInitial);
    ref.onDispose(() => _analysisSub?.cancel());
    return MealLogState(selectedDate: normalized);
  }

  Future<void> _loadInitial() async {
    await Future.wait([fetchLogsForSelectedDate(), refreshProfile()]);
  }

  /// Re-fetches the signed-in user's profile and updates
  /// [MealLogState.username]/[MealLogState.avatarPath]/[MealLogState.dailyTarget]
  /// — call after something outside this notifier (e.g. `PlanScreen`,
  /// `ProfileScreen`) changes the stored profile, so the home screen
  /// reflects it without a restart.
  Future<void> refreshProfile() async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;

    final profile = await ref.read(fetchUserProfileUseCaseProvider)(userId);
    if (profile == null) return;

    state = state.copyWith(
      username: profile.username,
      avatarPath: profile.avatarPath,
      dailyTarget: profile.dailyCalorieTarget ?? state.dailyTarget,
    );
  }

  /// Selects [date] to view, clamped to today — logging/viewing a future
  /// date has no meaning (a meal always logs with the real current
  /// timestamp), so this is a backstop against any entry point other than
  /// [WeekStrip]'s own disabled-future-day styling.
  Future<void> selectDate(DateTime date) async {
    final today = DateTime.now();
    final normalized = DateTime(date.year, date.month, date.day);
    final clamped =
        normalized.isAfter(DateTime(today.year, today.month, today.day))
        ? DateTime(today.year, today.month, today.day)
        : normalized;

    state = state.copyWith(selectedDate: clamped);
    await fetchLogsForSelectedDate();
  }

  Future<void> fetchLogsForSelectedDate() async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    final day = state.selectedDate ?? DateTime.now();
    if (userId == null) return;

    final logs = await ref.read(fetchMealLogsUseCaseProvider)(
      userId: userId,
      date: day,
    );
    state = state.copyWith(logs: logs);
  }

  /// Captures a photo (already taken by the caller via the custom camera
  /// screen), compresses/uploads it, and streams its nutrition analysis.
  /// Progress is staged as [MealLogState.streamingMealName]/[streamingItems]
  /// while [MealLogState.isStreaming] is true; the settled result lands in
  /// [MealLogState.pendingAnalysis] for the user to review on the
  /// scan-result screen.
  Future<void> analyzeCapturedPhoto(
    String imagePath, {
    MealType? mealType,
  }) async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) {
      state = state.copyWith(error: const NotSignedInException().message);
      return;
    }

    await _analysisSub?.cancel();
    _streamingStoragePath = null;
    state = state.copyWith(
      isProcessing: true,
      isStreaming: true,
      clearError: true,
      clearStreamingProgress: true,
    );

    // Give the UI a chance to actually paint the "analyzing" state before
    // the (synchronous, main-thread-blocking on web) image compression
    // starts — otherwise the screen can look frozen with no progress shown
    // at all until the whole request finishes. See
    // ImageRepositoryImpl.compressImage.
    await Future.delayed(Duration.zero);

    final completer = Completer<void>();
    _analysisSub = ref
        .read(analyzeMealPhotoUseCaseProvider)(
          userId: userId,
          imagePath: imagePath,
          mealType: mealType,
        )
        .listen(
          _handleStreamEvent,
          onError: (Object err) {
            state = state.copyWith(
              isProcessing: false,
              isStreaming: false,
              error: '$err',
            );
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

    await completer.future;
  }

  void _handleStreamEvent(MealAnalysisStreamEvent event) {
    switch (event) {
      case UploadCompleted(:final storagePath):
        _streamingStoragePath = storagePath;
      case MealNameDetected(:final mealName):
        state = state.copyWith(streamingMealName: mealName);
      case ItemDetected(:final item):
        state = state.copyWith(streamingItems: [...state.streamingItems, item]);
      case PendingAnalysisReady(:final pending):
        state = state.copyWith(
          pendingAnalysis: pending,
          isProcessing: false,
          isStreaming: false,
          clearStreamingProgress: true,
        );
      case AnalysisFailed(:final message):
        state = state.copyWith(
          isProcessing: false,
          isStreaming: false,
          error: message,
        );
      case AnalysisCompleted():
        // Superseded by PendingAnalysisReady before it reaches this
        // notifier — see AnalyzeMealPhotoUseCase.call.
        break;
    }
  }

  /// Stops an in-flight analysis early, keeping whatever ingredients were
  /// already detected as the pending analysis for review.
  Future<void> stopAnalyzing() async {
    if (!state.isStreaming) return;
    await _analysisSub?.cancel();
    _analysisSub = null;

    final storagePath = _streamingStoragePath;
    if (storagePath == null) {
      state = state.copyWith(
        isProcessing: false,
        isStreaming: false,
        clearStreamingProgress: true,
      );
      return;
    }

    state = state.copyWith(
      pendingAnalysis: PendingMealAnalysis(
        storagePath: storagePath,
        mealName: state.streamingMealName ?? 'Meal',
        healthScore: 5,
        items: state.streamingItems,
        mealType: MealType.forTime(DateTime.now()),
      ),
      isProcessing: false,
      isStreaming: false,
      clearStreamingProgress: true,
    );
  }

  /// Cancels an in-flight analysis before it's produced a pending result
  /// (e.g. the user backs out of the meal-detail screen while ingredients
  /// are still streaming in). Unlike [stopAnalyzing], this discards
  /// whatever was detected so far instead of keeping it for review.
  Future<void> cancelAnalysis() async {
    if (!state.isStreaming) return;
    await _analysisSub?.cancel();
    _analysisSub = null;

    final storagePath = _streamingStoragePath;
    _streamingStoragePath = null;
    state = state.copyWith(
      isProcessing: false,
      isStreaming: false,
      clearStreamingProgress: true,
    );

    if (storagePath != null) {
      await ref.read(discardPendingMealUseCaseProvider)(storagePath);
    }
  }

  void updateMealName(String mealName) {
    final pending = state.pendingAnalysis;
    if (pending == null) return;
    state = state.copyWith(
      pendingAnalysis: pending.copyWith(mealName: mealName),
    );
  }

  void setMealType(MealType mealType) {
    final pending = state.pendingAnalysis;
    if (pending == null) return;
    state = state.copyWith(
      pendingAnalysis: pending.copyWith(mealType: mealType),
    );
  }

  void setItemPortion(int index, double portion) {
    final pending = state.pendingAnalysis;
    if (pending == null) return;
    state = state.copyWith(
      pendingAnalysis: pending.withItemPortion(index, portion),
    );
  }

  /// Removes ingredient [index], returning the removed item so the caller
  /// can offer an "Undo" (see [restoreItem]) — or `null` if the removal was
  /// refused because it's the meal's last remaining ingredient.
  MealAnalysisItem? removeItem(int index) {
    final pending = state.pendingAnalysis;
    if (pending == null || pending.items.length <= 1) return null;
    final removed = pending.items[index];
    state = state.copyWith(pendingAnalysis: pending.withItemRemoved(index));
    return removed;
  }

  /// Undoes a [removeItem] call, putting [item] back at [index].
  void restoreItem(int index, MealAnalysisItem item) {
    final pending = state.pendingAnalysis;
    if (pending == null) return;
    state = state.copyWith(
      pendingAnalysis: pending.withItemInserted(index, item),
    );
  }

  /// Persists the currently pending analysis (with any manual edits) as a
  /// new meal log.
  Future<void> confirmMealLog() async {
    final pending = state.pendingAnalysis;
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (pending == null || userId == null) return;

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final newLog = await ref.read(confirmMealLogUseCaseProvider)(
        userId: userId,
        analysis: pending,
      );
      final isSelectedDay = _isSameDay(newLog.createdAt, state.selectedDate);
      state = state.copyWith(
        logs: isSelectedDay ? [newLog, ...state.logs] : state.logs,
        isProcessing: false,
        clearPendingAnalysis: true,
      );
    } catch (err) {
      state = state.copyWith(isProcessing: false, error: '$err');
    }
  }

  bool _isSameDay(DateTime a, DateTime? b) {
    if (b == null) return false;
    // [a] (a DB row's created_at, parsed as UTC) and [b] (selectedDate, a
    // local-midnight DateTime) must be compared in the same zone — see the
    // note in MealLogRemoteDataSource.fetchLogsForRange for the same class
    // of bug.
    final local = a.toLocal();
    return local.year == b.year && local.month == b.month && local.day == b.day;
  }

  /// Discards the pending analysis and removes its uploaded image.
  Future<void> discardPendingMeal() async {
    final pending = state.pendingAnalysis;
    if (pending == null) return;

    await ref.read(discardPendingMealUseCaseProvider)(pending.storagePath);
    state = state.copyWith(clearPendingAnalysis: true);
  }

  Future<String> signedImageUrl(String path) {
    return ref.read(getSignedImageUrlUseCaseProvider)(path);
  }

  /// Removes [log] from [MealLogState.logs] and commits its (soft) deletion
  /// to the backend immediately — no deferred commit, so nothing reading
  /// fresh from the backend (e.g. Ask AI) can observe a "deleted" meal as
  /// still-live. Returns the index [log] was removed from, or `null` if it
  /// wasn't found or the backend call failed ([MealLogState.error] is set
  /// in the latter case). Pairs with [restoreMealLog] if the user taps
  /// Undo before the snackbar showing this closes.
  Future<int?> deleteMealLog(MealLog log) async {
    final index = state.logs.indexWhere((l) => l.id == log.id);
    if (index == -1) return null;
    state = state.copyWith(logs: [...state.logs]..removeAt(index));
    try {
      await ref.read(deleteMealLogUseCaseProvider)(log.id);
    } catch (err) {
      state = state.copyWith(
        logs: [...state.logs]..insert(index, log),
        error: '$err',
      );
      return null;
    }
    return index;
  }

  /// Reverses [deleteMealLog]: puts [log] back at [index] and clears its
  /// backend soft-delete. On failure, [log] is removed from local state
  /// again (rather than showing a meal the backend still considers
  /// deleted) and [MealLogState.error] is set.
  Future<void> restoreMealLog(int index, MealLog log) async {
    state = state.copyWith(logs: [...state.logs]..insert(index, log));
    try {
      await ref.read(restoreMealLogUseCaseProvider)(log.id);
    } catch (err) {
      final idx = state.logs.indexWhere((l) => l.id == log.id);
      state = state.copyWith(
        logs: idx == -1 ? state.logs : ([...state.logs]..removeAt(idx)),
        error: '$err',
      );
    }
  }

  /// Persists edits made to an existing meal log (e.g. from the edit sheet
  /// opened by tapping a meal card) and swaps it into [MealLogState.logs].
  Future<void> updateMealLog(MealLog edited) async {
    try {
      final updated = await ref.read(updateMealLogUseCaseProvider)(edited);
      final index = state.logs.indexWhere((l) => l.id == updated.id);
      if (index == -1) return;
      state = state.copyWith(logs: [...state.logs]..[index] = updated);
    } catch (err) {
      state = state.copyWith(error: '$err');
    }
  }
}
