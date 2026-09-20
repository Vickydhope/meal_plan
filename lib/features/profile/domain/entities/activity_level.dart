/// Daily activity level, used as the TDEE multiplier on top of BMR in
/// `CalculateCalorieTargetUseCase`. Multipliers are the standard
/// Mifflin-St Jeor activity factors.
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  factory ActivityLevel.fromDbValue(String value) =>
      ActivityLevel.values.firstWhere((level) => level.dbValue == value);

  String get dbValue => switch (this) {
    ActivityLevel.veryActive => 'very_active',
    _ => name,
  };

  String get label => switch (this) {
    ActivityLevel.sedentary => 'Sedentary',
    ActivityLevel.light => 'Light',
    ActivityLevel.moderate => 'Moderate',
    ActivityLevel.active => 'Active',
    ActivityLevel.veryActive => 'Very Active',
  };

  String get description => switch (this) {
    ActivityLevel.sedentary => 'Little or no exercise',
    ActivityLevel.light => 'Exercise 1-3 days/week',
    ActivityLevel.moderate => 'Exercise 3-5 days/week',
    ActivityLevel.active => 'Exercise 6-7 days/week',
    ActivityLevel.veryActive => 'Hard exercise daily',
  };

  double get multiplier => switch (this) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
    ActivityLevel.veryActive => 1.9,
  };
}
