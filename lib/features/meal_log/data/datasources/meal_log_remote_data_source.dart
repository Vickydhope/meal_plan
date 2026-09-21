import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw Supabase access for the `meal_logs` table. Returns/accepts plain
/// maps — turning those into domain entities is the repository's job.
class MealLogRemoteDataSource {
  MealLogRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchLogsForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    // `start`/`end` are local-midnight boundaries; Postgrest has no timezone
    // context of its own, so an offset-less ISO string (e.g. from a local,
    // non-UTC DateTime) gets cast to timestamptz as if it *were* UTC —
    // shifting the window by the device's UTC offset. Converting to UTC
    // first keeps the boundaries pinned to the same real-world instants.
    final rows = await _client
        .from('meal_logs')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', end.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> insertMealLog(Map<String, dynamic> payload) {
    return _client.from('meal_logs').insert(payload).select().single();
  }

  /// Soft-deletes: stamps `deleted_at` rather than issuing a real `DELETE`,
  /// so [restoreMealLog] can cheaply undo it without losing the row's id or
  /// its Storage image. `.select().single()` forces a thrown
  /// PostgrestException when the update matches zero rows (e.g. RLS
  /// silently restricts it) — a bare `.update()` returns HTTP 200 either
  /// way, masking a no-op as success.
  Future<void> deleteMealLog(String id) async {
    await _client
        .from('meal_logs')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
  }

  /// Reverses [deleteMealLog] by clearing `deleted_at`.
  Future<void> restoreMealLog(String id) async {
    await _client
        .from('meal_logs')
        .update({'deleted_at': null})
        .eq('id', id)
        .select()
        .single();
  }

  Future<Map<String, dynamic>> updateMealLog(
    String id,
    Map<String, dynamic> payload,
  ) {
    return _client
        .from('meal_logs')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
  }
}
