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
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', end.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> insertMealLog(Map<String, dynamic> payload) {
    return _client.from('meal_logs').insert(payload).select().single();
  }

  Future<void> deleteMealLog(String id) {
    return _client.from('meal_logs').delete().eq('id', id);
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
