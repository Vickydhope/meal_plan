/// Body-weight history stored on the backend (`weight_logs`). Changes to the
/// profile's weight are recorded server-side; this adds imported readings.
abstract class WeightLogRepository {
  /// [userId]'s readings logged in `[start, end)`, oldest first.
  Future<List<({double kg, DateTime measuredAt})>> fetchWeights({
    required String userId,
    required DateTime start,
    required DateTime end,
  });

  /// Stores [weights]; readings already stored at the same instant are
  /// skipped, so re-importing is safe.
  Future<void> importWeights(
    String userId,
    List<({double kg, DateTime measuredAt})> weights,
  );
}
