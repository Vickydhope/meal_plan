import '../../../meal_log/domain/entities/meal_analysis_item.dart';
import '../../../meal_log/domain/entities/meal_type.dart';
import '../../../meal_log/domain/entities/pending_meal_analysis.dart';

/// An AI-suggested meal for later today.
class MealSuggestion {
  const MealSuggestion({
    required this.mealType,
    required this.mealName,
    required this.description,
    required this.healthScore,
    required this.items,
  });

  final MealType mealType;
  final String mealName;
  final String description;
  final int healthScore;
  final List<MealAnalysisItem> items;

  /// As a meal ready for review, like a scan with no photo.
  PendingMealAnalysis toPending() => PendingMealAnalysis(
    storagePath: null,
    mealName: mealName,
    healthScore: healthScore,
    items: items,
    mealType: mealType,
  );
}

/// What's left of today's budget, and the meals still to come.
class RemainingDay {
  const RemainingDay({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.mealTypes,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final List<MealType> mealTypes;
}
