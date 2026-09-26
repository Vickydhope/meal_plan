import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/repositories/weight_log_repository.dart';

/// `weight_logs` table access — talks to [SupabaseClient] directly, like
/// `ActivityLogRepositoryImpl`.
class WeightLogRepositoryImpl implements WeightLogRepository {
  WeightLogRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _table = 'weight_logs';

  @override
  Future<List<({double kg, DateTime measuredAt})>> fetchWeights({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final rows = await _client
          .from(_table)
          .select('weight_kg, logged_at')
          .eq('user_id', userId)
          .gte('logged_at', start.toUtc().toIso8601String())
          .lt('logged_at', end.toUtc().toIso8601String())
          .order('logged_at');
      return [
        for (final row in rows)
          (
            kg: (row['weight_kg'] as num).toDouble(),
            measuredAt: DateTime.parse(row['logged_at'] as String).toLocal(),
          ),
      ];
    } catch (err) {
      throw MealLogPersistenceException('Failed to load weight history: $err');
    }
  }

  @override
  Future<void> importWeights(
    String userId,
    List<({double kg, DateTime measuredAt})> weights,
  ) async {
    if (weights.isEmpty) return;
    try {
      await _client
          .from(_table)
          .upsert(
            [
              for (final w in weights)
                {
                  'user_id': userId,
                  'weight_kg': w.kg,
                  'logged_at': w.measuredAt.toUtc().toIso8601String(),
                },
            ],
            onConflict: 'user_id,logged_at',
            ignoreDuplicates: true,
          );
    } catch (err) {
      throw MealLogPersistenceException('Failed to save weight history: $err');
    }
  }
}
