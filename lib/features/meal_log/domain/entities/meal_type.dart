/// The meal-of-day bucket a logged meal belongs to, used to group the home
/// screen's activity feed into Breakfast/Lunch/Dinner sections.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  /// Infers a meal type from the time of day, used as the default when a
  /// photo is analyzed (before the user can override it).
  factory MealType.forTime(DateTime time) {
    if (time.hour < 11) return MealType.breakfast;
    if (time.hour < 16) return MealType.lunch;
    return MealType.dinner;
  }

  /// Parses the `meal_type` column value, defaulting unknown/legacy values
  /// (including the DB default `'other'`) to [snack].
  factory MealType.fromDbValue(String? value) {
    return MealType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => MealType.snack,
    );
  }

  String get dbValue => name;

  String get label => switch (this) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
    MealType.snack => 'Snack',
  };
}
