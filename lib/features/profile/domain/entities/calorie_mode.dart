/// How the daily calorie budget is set — chosen on `PlanScreen`.
enum CalorieMode {
  /// The plan target from the self-reported activity level, every day.
  fixed,

  /// The target at a sedentary level plus the active energy synced from a
  /// health app that day (see `CalculateActivityAdjustedTargetUseCase`).
  dynamic;

  /// Unknown/missing values fall back to [fixed], the column default.
  factory CalorieMode.fromDbValue(String? value) => CalorieMode.values
      .firstWhere((mode) => mode.name == value, orElse: () => fixed);

  String get dbValue => name;

  String get label => switch (this) {
    CalorieMode.fixed => 'Fixed',
    CalorieMode.dynamic => 'Activity-based',
  };
}
