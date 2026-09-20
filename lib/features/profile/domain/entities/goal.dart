/// The user's weight goal, applied as a flat daily calorie adjustment on
/// top of TDEE in `CalculateCalorieTargetUseCase`.
enum Goal {
  lose,
  maintain,
  gain;

  factory Goal.fromDbValue(String value) => Goal.values.byName(value);

  String get dbValue => name;

  String get label => switch (this) {
    Goal.lose => 'Lose Weight',
    Goal.maintain => 'Maintain Weight',
    Goal.gain => 'Gain Weight',
  };

  /// Daily calorie adjustment for a ~1lb/week rate of change.
  int get calorieAdjustment => switch (this) {
    Goal.lose => -500,
    Goal.maintain => 0,
    Goal.gain => 500,
  };
}
