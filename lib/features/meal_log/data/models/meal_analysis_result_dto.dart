import '../../domain/entities/pending_meal_analysis.dart';
import 'meal_analysis_item_dto.dart';

/// Wraps the JSON body returned by the analyze-food edge function.
class MealAnalysisResultDto {
  const MealAnalysisResultDto({
    required this.mealName,
    required this.healthScore,
    required this.items,
  });

  factory MealAnalysisResultDto.fromMap(Map<String, dynamic> map) {
    final items = ((map['items'] as List?) ?? const [])
        .map((item) => MealAnalysisItemDto.fromMap(item as Map<String, dynamic>))
        .toList();

    return MealAnalysisResultDto(
      mealName: map['meal_name'] as String? ?? 'Meal',
      healthScore: (map['health_score'] as num?)?.round() ?? 5,
      items: items,
    );
  }

  final String mealName;
  final int healthScore;
  final List<MealAnalysisItemDto> items;

  MealAnalysisResult toEntity() => MealAnalysisResult(
        mealName: mealName,
        healthScore: healthScore,
        items: items.map((dto) => dto.toEntity()).toList(),
      );
}
