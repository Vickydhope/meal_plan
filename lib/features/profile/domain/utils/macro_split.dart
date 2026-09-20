/// A protein/carbs/fat gram breakdown of a calorie target.
class MacroSplit {
  const MacroSplit({
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;

  /// Standard 30/40/30 (protein/carbs/fat) calorie split at 4/4/9
  /// kcal-per-gram — used consistently by both the onboarding summary and
  /// the home screen's macro targets.
  factory MacroSplit.fromCalories(int calories) => MacroSplit(
    proteinGrams: (calories * 0.3 / 4).round(),
    carbsGrams: (calories * 0.4 / 4).round(),
    fatGrams: (calories * 0.3 / 9).round(),
  );
}
