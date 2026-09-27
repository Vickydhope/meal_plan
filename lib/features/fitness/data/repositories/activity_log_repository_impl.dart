import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/daily_activity.dart';
import '../../domain/repositories/activity_log_repository.dart';

/// `daily_activity` table access. Small enough (three one-line queries)
/// that it talks to [SupabaseClient] directly instead of via a separate
/// datasource class.
class ActivityLogRepositoryImpl implements ActivityLogRepository {
  ActivityLogRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _table = 'daily_activity';

  /// The local calendar date as `YYYY-MM-DD` — the `day` column's key.
  static String _dayKey(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).toIso8601String().split('T').first;

  @override
  Future<void> saveActivity(String userId, DailyActivity activity) =>
      saveActivities(userId, [activity]);

  @override
  Future<void> saveActivities(
    String userId,
    List<DailyActivity> activities,
  ) async {
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    try {
      // ponytail: last write wins if two devices both sync Health for the
      // same account; switch to an RPC taking greatest() if that happens.
      await _client.from(_table).upsert([
        for (final activity in activities)
          {
            'user_id': userId,
            'day': _dayKey(activity.date),
            'steps': activity.steps,
            'active_energy_kcal': activity.activeEnergyBurnedKcal,
            'updated_at': updatedAt,
          },
      ]);
    } catch (err) {
      throw MealLogPersistenceException('Failed to save activity: $err');
    }
  }

  @override
  Future<DailyActivity?> fetchActivity(String userId, DateTime day) async {
    try {
      final row = await _client
          .from(_table)
          .select('steps, active_energy_kcal')
          .eq('user_id', userId)
          .eq('day', _dayKey(day))
          .maybeSingle();
      if (row == null) return null;
      return DailyActivity(
        date: DateTime(day.year, day.month, day.day),
        steps: (row['steps'] as num).toInt(),
        activeEnergyBurnedKcal: (row['active_energy_kcal'] as num).toInt(),
      );
    } catch (err) {
      throw MealLogPersistenceException('Failed to load activity: $err');
    }
  }

  @override
  Future<void> deleteActivity(String userId, DateTime day) async {
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', userId)
          .eq('day', _dayKey(day));
    } catch (err) {
      throw MealLogPersistenceException('Failed to remove activity: $err');
    }
  }
}
