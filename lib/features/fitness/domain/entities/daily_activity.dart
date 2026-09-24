/// Activity read from the platform health store (HealthKit / Health
/// Connect) for a single local calendar day.
class DailyActivity {
  const DailyActivity({
    required this.date,
    required this.steps,
    required this.activeEnergyBurnedKcal,
  });

  final DateTime date;
  final int steps;
  final int activeEnergyBurnedKcal;
}
