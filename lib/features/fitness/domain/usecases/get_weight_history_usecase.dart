import '../../../../core/error/app_exception.dart';
import '../repositories/fitness_repository.dart';
import '../repositories/weight_log_repository.dart';

/// Body weight over the last [days] local days ending today, at most one
/// reading per day (the day's last), oldest first. With Health sync on,
/// first imports the window's readings from the health store, so history
/// from before this feature (or from a smart scale) shows up too.
class GetWeightHistoryUseCase {
  GetWeightHistoryUseCase(this._fitness, this._weightLogs);

  final FitnessRepository _fitness;
  final WeightLogRepository _weightLogs;

  Future<List<({double kg, DateTime measuredAt})>> call({
    required String userId,
    required int days,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day - days + 1);
    final end = DateTime(today.year, today.month, today.day + 1);

    if (await _fitness.isSyncEnabled()) {
      try {
        await _weightLogs.importWeights(
          userId,
          await _fitness.getWeights(start: start, end: end),
        );
      } on AppException {
        // Health unreachable or the import failed: still show what's stored.
      }
    }

    final byDay = <DateTime, ({double kg, DateTime measuredAt})>{};
    final weights = await _weightLogs.fetchWeights(
      userId: userId,
      start: start,
      end: end,
    );
    for (final w in weights) {
      final t = w.measuredAt;
      // Oldest first, so a later reading on the same day overwrites.
      byDay[DateTime(t.year, t.month, t.day)] = w;
    }
    return byDay.values.toList();
  }
}
