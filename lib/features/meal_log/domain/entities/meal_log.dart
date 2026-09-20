import 'meal_analysis_item.dart';
import 'meal_type.dart';

/// A persisted meal log entry.
class MealLog {
  const MealLog({
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

  /// Per-ingredient breakdown (with portion multipliers), from
  /// `raw_json_data.items` — empty for logs saved before this was tracked.
  final List<MealAnalysisItem> items;
}
