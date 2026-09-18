import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/image_service.dart';
import 'meal_log_model.dart';

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

final mealLogProvider =
    NotifierProvider<MealLogNotifier, MealLogState>(MealLogNotifier.new);

class MealLogNotifier extends Notifier<MealLogState> {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  MealLogState build() {
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    Future.microtask(_loadInitial);
    return MealLogState(selectedDate: normalized);
  }

  Future<void> _loadInitial() async {
    await Future.wait([fetchLogsForSelectedDate(), _fetchProfile()]);
  }

  Future<void> _fetchProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final row = await _client
        .from('profiles')
        .select('username, daily_calorie_target')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return;
    final target = (row['daily_calorie_target'] as num?)?.toInt();
    state = state.copyWith(
      username: row['username'] as String?,
      dailyTarget: target ?? state.dailyTarget,
    );
  }

  Future<void> selectDate(DateTime date) async {
    state = state.copyWith(
      selectedDate: DateTime(date.year, date.month, date.day),
    );
    await fetchLogsForSelectedDate();
  }

  Future<void> fetchLogsForSelectedDate() async {
    final userId = _client.auth.currentUser?.id;
    final day = state.selectedDate ?? DateTime.now();
    if (userId == null) return;

    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows = await _client
        .from('meal_logs')
        .select()
        .eq('user_id', userId)
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String())
        .order('created_at', ascending: false);

    final logs = (rows as List)
        .map((row) => MealLog.fromMap(row as Map<String, dynamic>))
        .toList();

    state = state.copyWith(logs: logs);
  }

  /// Captures a photo (already taken by the caller via the custom camera
  /// screen), compresses/uploads it, and sends it to the analyze-food edge
  /// function. Result is staged as [MealLogState.pendingAnalysis] for the
  /// user to review on the scan-result screen.
  Future<void> analyzeCapturedPhoto(String imagePath) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(error: 'Sign in to log a meal');
      return;
    }

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final imageService = ref.read(imageServiceProvider);
      final bytes = await imageService.compressBytesFromPath(imagePath);
      final storagePath = await imageService.uploadBytes(bytes);

      final response = await _client.functions.invoke(
        'analyze-food',
        body: {
          'image': base64Encode(bytes),
          'mimeType': 'image/jpeg',
        },
      );

      final data = response.data as Map<String, dynamic>;

      state = state.copyWith(
        pendingAnalysis: PendingMealAnalysis.fromGeminiResponse(
          storagePath: storagePath,
          data: data,
        ),
        isProcessing: false,
      );
    } catch (err) {
      state = state.copyWith(isProcessing: false, error: '$err');
    }
  }

  void updateMealName(String mealName) {
    final pending = state.pendingAnalysis;
    if (pending == null) return;
    state = state.copyWith(
      pendingAnalysis: pending.copyWith(mealName: mealName),
    );
  }

  void setItemPortion(int index, double portion) {
    final pending = state.pendingAnalysis;
    if (pending == null) return;
    state = state.copyWith(
      pendingAnalysis: pending.withItemPortion(index, portion),
    );
  }

  /// Persists the currently pending analysis (with any manual edits) as a
  /// new meal log.
  Future<void> confirmMealLog() async {
    final pending = state.pendingAnalysis;
    final userId = _client.auth.currentUser?.id;
    if (pending == null || userId == null) return;

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final inserted = await _client
          .from('meal_logs')
          .insert({
            'user_id': userId,
            'image_url': pending.storagePath,
            'meal_name': pending.mealName,
            'total_calories': pending.totalCalories,
            'total_protein': pending.totalProtein,
            'total_carbs': pending.totalCarbs,
            'total_fats': pending.totalFats,
            'health_score': pending.healthScore,
            'raw_json_data': {
              'items': pending.items.map((item) => item.toMap()).toList(),
            },
          })
          .select()
          .single();

      final newLog = MealLog.fromMap(inserted);
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
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Discards the pending analysis and removes its uploaded image so it
  /// doesn't sit unused in storage.
  Future<void> discardPendingMeal() async {
    final pending = state.pendingAnalysis;
    if (pending == null) return;

    try {
      await _client.storage.from('food-images').remove([pending.storagePath]);
    } catch (_) {
      // Best-effort cleanup; not worth surfacing to the user.
    }

    state = state.copyWith(clearPendingAnalysis: true);
  }

  Future<String> signedImageUrl(String path) {
    return ref.read(imageServiceProvider).signedUrl(path);
  }
}
