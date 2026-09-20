import '../../domain/entities/meal_analysis_item.dart';
import '../../domain/entities/meal_log.dart';
import '../../domain/entities/meal_type.dart';
import 'meal_analysis_item_dto.dart';

class MealLogDto {
  const MealLogDto({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.mealName,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
    required this.healthScore,
    required this.createdAt,
    required this.mealType,
    required this.items,
  });

  factory MealLogDto.fromMap(Map<String, dynamic> map) {
    final rawItems =
        (map['raw_json_data'] as Map<String, dynamic>?)?['items']
            as List<dynamic>?;

    return MealLogDto(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      imageUrl: map['image_url'] as String?,
      mealName: map['meal_name'] as String? ?? 'Meal',
      totalCalories: (map['total_calories'] as num?)?.toInt() ?? 0,
      totalProtein: (map['total_protein'] as num?)?.toInt() ?? 0,
      totalCarbs: (map['total_carbs'] as num?)?.toInt() ?? 0,
      totalFats: (map['total_fats'] as num?)?.toInt() ?? 0,
      healthScore: (map['health_score'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      mealType: MealType.fromDbValue(map['meal_type'] as String?),
      items: rawItems == null
          ? const []
          : rawItems
                .map(
                  (item) =>
                      MealAnalysisItemDto.fromMap(item as Map<String, dynamic>)
                          .toEntity(),
                )
                .toList(),
    );
  }

  final String id;
  final String userId;
  final String? imageUrl;
  final String mealName;
  final int totalCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFats;
  final int healthScore;
  final DateTime createdAt;
  final MealType mealType;
  final List<MealAnalysisItem> items;

  MealLog toEntity() => MealLog(
    id: id,
    userId: userId,
    imageUrl: imageUrl,
    mealName: mealName,
    totalCalories: totalCalories,
    totalProtein: totalProtein,
    totalCarbs: totalCarbs,
    totalFats: totalFats,
    healthScore: healthScore,
    createdAt: createdAt,
    mealType: mealType,
    items: items,
  );
}
