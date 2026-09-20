import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchProfile(String userId) {
    return _client
        .from('profiles')
        .select(
          'username, full_name, phone, avatar_path, daily_calorie_target, '
          'sex, date_of_birth, height_cm, weight_kg, activity_level, goal, '
          'onboarding_completed_at',
        )
        .eq('id', userId)
        .maybeSingle();
  }

  /// Upserts [values] into `profiles`, keyed on `id` — a fresh account has
  /// no row yet, so this must be an upsert rather than an update.
  Future<void> upsertProfile(Map<String, dynamic> values) {
    return _client.from('profiles').upsert(values, onConflict: 'id');
  }
}
