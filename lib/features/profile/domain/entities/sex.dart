/// Biological sex, used only for the Mifflin-St Jeor BMR calculation during
/// onboarding — see `CalculateCalorieTargetUseCase`.
enum Sex {
  male,
  female;

  factory Sex.fromDbValue(String value) => Sex.values.byName(value);

  String get dbValue => name;

  String get label => switch (this) {
    Sex.male => 'Male',
    Sex.female => 'Female',
  };
}
