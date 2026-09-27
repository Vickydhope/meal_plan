import 'dart:async';

import 'package:flutter/material.dart' show DateUtils;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../domain/entities/meal_log.dart';
import '../../domain/entities/pending_meal_analysis.dart';
import '../providers/meal_log_providers.dart';
import '../state/meal_log_state.dart';

/// Presentation-layer orchestrator. Pulls its dependencies (use cases,
/// [AuthRepository]) from providers rather than talking to Supabase or any
/// other infra package directly — everything it does goes through the
/// domain layer.
class MealLogNotifier extends Notifier<MealLogState> {
  /// Bumped by every fetch, so an older one (e.g. for a day since switched
  /// away from) knows not to apply its result.
  int _fetchId = 0;

  /// Bumped by every change to [MealLogState.logs], so a fetch can tell a
  /// save/delete landed while it was in flight.
  int _logEdits = 0;

  @override
  set state(MealLogState value) {
    if (!identical(value.logs, stateOrNull?.logs)) _logEdits++;
    super.state = value;
  }

  @override
  MealLogState build() {
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    Future.microtask(fetchLogsForSelectedDate);
    return MealLogState(selectedDate: normalized);
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

    final id = ++_fetchId;
    state = state.copyWith(isLoadingLogs: true);
    while (true) {
      final edits = _logEdits;
      final logs = await ref.read(fetchMealLogsUseCaseProvider)(
        userId: userId,
        date: day,
      );
      if (id != _fetchId) return; // A newer fetch owns the list now.
      // A save/delete during the fetch is already in the backend, but this
      // result may predate it — fetch again rather than overwrite it.
      if (edits != _logEdits) continue;
      state = state.copyWith(logs: logs, isLoadingLogs: false);
      return;
    }
  }

  /// Saves a reviewed [pending] meal (see [ScanSessionNotifier.confirm]).
  /// Returns the new log, or `null` on failure ([MealLogState.error] is set).
  Future<MealLog?> logMeal(PendingMealAnalysis pending) async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return null;
    return _saveMeal(
      () => ref.read(confirmMealLogUseCaseProvider)(
        userId: userId,
        analysis: pending,
      ),
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
