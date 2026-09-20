import '../../domain/entities/meal_analysis_item.dart';

/// Wire format for a [MealAnalysisItem], both as returned by the
/// analyze-food function and as stored in `meal_logs.raw_json_data`.
class MealAnalysisItemDto {
  const MealAnalysisItemDto({
    required this.foodName,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    this.portion = 1.0,
  });

  factory MealAnalysisItemDto.fromMap(Map<String, dynamic> map) {
    return MealAnalysisItemDto(
      foodName: map['food_name'] as String? ?? 'Unknown item',
      estimatedWeightG: (map['estimated_weight_g'] as num?)?.toDouble() ?? 0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toDouble() ?? 0,
      fatsG: (map['fats_g'] as num?)?.toDouble() ?? 0,
      portion: (map['portion'] as num?)?.toDouble() ?? 1.0,
    );
  }

  factory MealAnalysisItemDto.fromEntity(MealAnalysisItem item) {
    return MealAnalysisItemDto(
      foodName: item.foodName,
      estimatedWeightG: item.estimatedWeightG,
      calories: item.calories,
      proteinG: item.proteinG,
      carbsG: item.carbsG,
      fatsG: item.fatsG,
      portion: item.portion,
    );
  }

  final String foodName;
  final double estimatedWeightG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatsG;
  final double portion;

  MealAnalysisItem toEntity() => MealAnalysisItem(
    foodName: foodName,
    estimatedWeightG: estimatedWeightG,
    calories: calories,
    proteinG: proteinG,
    carbsG: carbsG,
    fatsG: fatsG,
    portion: portion,
  );

  Map<String, dynamic> toMap() => {
    'food_name': foodName,
    'estimated_weight_g': estimatedWeightG,
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fats_g': fatsG,
    'portion': portion,
  };
}
