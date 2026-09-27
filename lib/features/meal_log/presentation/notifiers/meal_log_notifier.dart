import 'dart:async';

import 'package:flutter/material.dart' show DateUtils;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
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

  /// True while a photo analysis hasn't uploaded its photo yet, so there's
  /// nothing reviewable to keep if it's stopped.
  bool _awaitingUpload = false;

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

  /// Syncs [MealLogState.username]/[MealLogState.avatarPath]/[MealLogState.dailyTarget]
  /// from [currentUserProfileProvider] — call after invalidating that
  /// provider when something outside this notifier (e.g. `NutritionGoalsScreen`,
  /// `ProfileScreen`) changes the stored profile, so the home screen
  /// reflects it without a restart. Reads the shared provider rather than
  /// fetching directly, so the router and this notifier share one request.
  Future<void> refreshProfile() async {
    final profile = await ref.read(currentUserProfileProvider.future);
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

    // Clear the previous day's logs immediately so the screen doesn't show
    // stale data while the new day's logs are in flight.
    state = state.copyWith(
      selectedDate: clamped,
      logs: const [],
      isLoadingLogs: true,
    );
    await fetchLogsForSelectedDate();
  }

  Future<void> fetchLogsForSelectedDate() async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    final day = state.selectedDate ?? DateTime.now();
    if (userId == null) return;

    state = state.copyWith(isLoadingLogs: true);
    final logs = await ref.read(fetchMealLogsUseCaseProvider)(
      userId: userId,
      date: day,
    );
    state = state.copyWith(logs: logs, isLoadingLogs: false);
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
    await _analyze(
      () => ref.read(analyzeMealPhotoUseCaseProvider)(
        userId: userId,
        imagePath: imagePath,
        mealType: mealType,
      ),
      awaitsUpload: true,
    );
  }

  /// Like [analyzeCapturedPhoto], for a typed description of the meal —
  /// same streaming progress and review, but no photo.
  Future<void> analyzeDescription(String description, {MealType? mealType}) {
    return _analyze(
      () => ref
          .read(analyzeMealPhotoUseCaseProvider)
          .fromDescription(description: description, mealType: mealType),
      awaitsUpload: false,
    );
  }

  /// Like [analyzeCapturedPhoto], for a scanned packaged-food barcode — the
  /// product's nutrition facts come from a lookup, not image analysis.
  Future<void> analyzeBarcode(String barcode, {MealType? mealType}) {
    return _analyze(
      () => ref.read(lookUpBarcodeUseCaseProvider)(
        barcode: barcode,
        mealType: mealType,
      ),
      awaitsUpload: false,
    );
  }

  /// Stages an already-complete meal (e.g. an AI suggestion) for review,
  /// with no analysis to run.
  void reviewMeal(PendingMealAnalysis pending) {
    _analysisSub?.cancel();
    _analysisSub = null;
    _awaitingUpload = false;
    state = state.copyWith(
      pendingAnalysis: pending,
      isProcessing: false,
      isStreaming: false,
      clearError: true,
      clearStreamingProgress: true,
    );
  }

  /// Runs one analysis stream, staging its progress in state. With
  /// [awaitsUpload], the result can't be reviewed until the photo's
  /// [UploadCompleted] arrives (see [stopAnalyzing]).
  Future<void> _analyze(
    Stream<MealAnalysisStreamEvent> Function() start, {
    required bool awaitsUpload,
  }) async {
    await _analysisSub?.cancel();
    _streamingStoragePath = null;
    _awaitingUpload = awaitsUpload;
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
    _analysisSub = start().listen(
      _handleStreamEvent,
      onError: (Object err) {
        state = state.copyWith(
          isProcessing: false,
          isStreaming: false,
          error: userMessageFor(err),
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
        _awaitingUpload = false;
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
    // Aborts the in-flight HTTP call first — cancelling the subscription
    // alone can't interrupt a single network request already in flight, so
    // without this the cancel below just blocks until Gemini responds on
    // its own (see AnalyzeMealPhotoUseCase.cancelInFlight).
    ref.read(analyzeMealPhotoUseCaseProvider).cancelInFlight();
    await _analysisSub?.cancel();
    _analysisSub = null;

    final storagePath = _streamingStoragePath;
    if (_awaitingUpload) {
      // Stopped before the upload even finished, so there's no image to
      // build a PendingMealAnalysis from and nothing to review — surface
      // as an error rather than silently sitting in the "analyzing" phase
      // with a Stop button that can no longer do anything (isStreaming is
      // now false, so a second tap would just no-op).
      state = state.copyWith(
        isProcessing: false,
        isStreaming: false,
        error: 'Analysis stopped.',
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
    ref.read(analyzeMealPhotoUseCaseProvider).cancelInFlight();
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
    final saved = await _saveMeal(
      () => ref.read(confirmMealLogUseCaseProvider)(
        userId: userId,
        analysis: pending,
      ),
    );
    state = state.copyWith(
      isProcessing: false,
      clearPendingAnalysis: saved != null,
    );
  }

  /// Logs a copy of [log] as eaten now (see [RelogMealUseCase]). Returns
  /// the new log, or `null` on failure ([MealLogState.error] is set).
  Future<MealLog?> relogMeal(MealLog log) async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return null;
    return _saveMeal(
      () => ref.read(relogMealUseCaseProvider)(userId: userId, log: log),
    );
  }

  /// Runs [save], then does everything a newly logged meal needs: Health
  /// mirror, notification badge, reminders, and the visible day's list.
  Future<MealLog?> _saveMeal(Future<MealLog> Function() save) async {
    try {
      final newLog = await save();
      _mirrorToHealth(() => ref.read(writeMealToHealthUseCaseProvider)(newLog));
      // The insert trigger just wrote a feed row; refresh the bell badge.
      ref.invalidate(notificationsProvider);
      _mealsChanged();
      // createdAt (a DB row's created_at, parsed as UTC) and selectedDate (a
      // local-midnight DateTime) must be compared in the same zone — see the
      // note in MealLogRemoteDataSource.fetchLogsForRange for the same class
      // of bug.
      final isSelectedDay = DateUtils.isSameDay(
        newLog.createdAt.toLocal(),
        state.selectedDate,
      );
      if (isSelectedDay) state = state.copyWith(logs: [newLog, ...state.logs]);
      return newLog;
    } catch (err) {
      state = state.copyWith(error: userMessageFor(err));
      return null;
    }
  }

  /// Today's logged meal types decide which reminders are skipped.
  void _mealsChanged() => ref.invalidate(reminderSyncProvider);

  /// Fire-and-forget: the meal is already saved, and the health store is
  /// only a mirror, so a failure there is reported and surfaced via
  /// [MealLogState.error] without touching the saved meal.
  void _mirrorToHealth(Future<void> Function() op) {
    // Future.sync: a synchronous throw must not escape into the caller's
    // try/catch and roll back a meal change that did succeed.
    unawaited(
      Future.sync(op).catchError((Object err, StackTrace stack) {
        Sentry.captureException(err, stackTrace: stack);
        state = state.copyWith(error: userMessageFor(err));
      }),
    );
  }

  /// Discards the pending analysis and removes its uploaded image.
  Future<void> discardPendingMeal() async {
    final pending = state.pendingAnalysis;
    if (pending == null) return;

    if (pending.storagePath case final path?) {
      await ref.read(discardPendingMealUseCaseProvider)(path);
    }
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
      _mirrorToHealth(() => ref.read(removeMealFromHealthUseCaseProvider)(log));
      _mealsChanged();
    } catch (err) {
      state = state.copyWith(
        logs: [...state.logs]..insert(index, log),
        error: userMessageFor(err),
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
      _mirrorToHealth(() => ref.read(writeMealToHealthUseCaseProvider)(log));
      _mealsChanged();
    } catch (err) {
      final idx = state.logs.indexWhere((l) => l.id == log.id);
      state = state.copyWith(
        logs: idx == -1 ? state.logs : ([...state.logs]..removeAt(idx)),
        error: userMessageFor(err),
      );
    }
  }

  /// Persists edits made to an existing meal log (e.g. from the edit sheet
  /// opened by tapping a meal card) and swaps it into [MealLogState.logs].
  Future<void> updateMealLog(MealLog edited) async {
    try {
      final updated = await ref.read(updateMealLogUseCaseProvider)(edited);
      _mirrorToHealth(
        () => ref.read(writeMealToHealthUseCaseProvider)(updated),
      );
      _mealsChanged();
      final index = state.logs.indexWhere((l) => l.id == updated.id);
      if (index == -1) return;
      state = state.copyWith(logs: [...state.logs]..[index] = updated);
    } catch (err) {
      state = state.copyWith(error: userMessageFor(err));
    }
  }
}
