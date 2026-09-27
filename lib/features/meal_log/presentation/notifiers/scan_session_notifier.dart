import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/meal_analysis_item.dart';
import '../../domain/entities/meal_analysis_stream_event.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/pending_meal_analysis.dart';
import '../providers/meal_log_providers.dart';
import '../state/scan_session_state.dart';

/// The scan → review → confirm flow behind `ScanResultScreen`: runs one
/// analysis stream at a time, holds the result for editing, and hands the
/// confirmed meal to [MealLogNotifier.logMeal].
class ScanSessionNotifier extends Notifier<ScanSessionState> {
  StreamSubscription<MealAnalysisStreamEvent>? _analysisSub;
  String? _streamingStoragePath;

  /// True while a photo analysis hasn't uploaded its photo yet, so there's
  /// nothing reviewable to keep if it's stopped.
  bool _awaitingUpload = false;

  @override
  ScanSessionState build() {
    ref.onDispose(() => _analysisSub?.cancel());
    return const ScanSessionState();
  }

  /// Captures a photo (already taken by the caller via the custom camera
  /// screen), compresses/uploads it, and streams its nutrition analysis.
  /// Progress is staged as [ScanSessionState.streamingMealName]/[streamingItems]
  /// while [ScanSessionState.isStreaming] is true; the settled result lands in
  /// [ScanSessionState.pendingAnalysis] for the user to review on the
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

  /// Saves the pending analysis (with any manual edits) as a new meal log.
  /// Returns whether it was saved; on failure the day's list surfaces the
  /// error (see [MealLogNotifier.logMeal]).
  Future<bool> confirm() async {
    final pending = state.pendingAnalysis;
    if (pending == null) return false;

    state = state.copyWith(isProcessing: true, clearError: true);
    final saved = await ref.read(mealLogProvider.notifier).logMeal(pending);
    state = state.copyWith(
      isProcessing: false,
      clearPendingAnalysis: saved != null,
    );
    return saved != null;
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
}
