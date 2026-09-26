import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/repositories/water_repository.dart';

/// `daily_water` table access — talks to [SupabaseClient] directly, like
/// `ActivityLogRepositoryImpl`.
class WaterRepositoryImpl implements WaterRepository {
  WaterRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _table = 'daily_water';

  /// The local calendar date as `YYYY-MM-DD` — the `day` column's key.
  static String _dayKey(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).toIso8601String().split('T').first;

  @override
  Future<int> fetchWater(String userId, DateTime day) async {
    try {
      final row = await _client
          .from(_table)
          .select('ml')
          .eq('user_id', userId)
          .eq('day', _dayKey(day))
          .maybeSingle();
      return (row?['ml'] as num?)?.toInt() ?? 0;
    } catch (err) {
      throw MealLogPersistenceException('Failed to load water: $err');
    }
  }

  @override
  Future<void> saveWater(String userId, DateTime day, int ml) async {
    try {
      await _client.from(_table).upsert({
        'user_id': userId,
        'day': _dayKey(day),
        'ml': ml,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (err) {
      throw MealLogPersistenceException('Failed to save water: $err');
    }
  }
}
