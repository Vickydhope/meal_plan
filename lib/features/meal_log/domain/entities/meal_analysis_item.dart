/// A single ingredient detected during food analysis, with a
/// user-adjustable portion multiplier (1.0 = the estimated portion as
/// photographed).
class MealAnalysisItem {
  const MealAnalysisItem({
    required this.foodName,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    this.portion = 1.0,
  });

  final String foodName;
  final double estimatedWeightG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatsG;
  final double portion;

  double get adjustedWeightG => estimatedWeightG * portion;
  double get adjustedCalories => calories * portion;
  double get adjustedProteinG => proteinG * portion;
  double get adjustedCarbsG => carbsG * portion;
  double get adjustedFatsG => fatsG * portion;

  MealAnalysisItem copyWith({double? portion}) {
    return MealAnalysisItem(
      foodName: foodName,
      estimatedWeightG: estimatedWeightG,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatsG: fatsG,
      portion: portion ?? this.portion,
    );
  }
}
