/// Millilitres of water drunk per local calendar day.
abstract class WaterRepository {
  /// [day]'s total, or 0 if nothing was logged.
  Future<int> fetchWater(String userId, DateTime day);

  Future<void> saveWater(String userId, DateTime day, int ml);
}
