import 'meal_analysis_item.dart';
import 'meal_type.dart';

/// A meal that has been analyzed and uploaded but not yet confirmed/saved.
/// The meal name is directly editable; totals are derived from [items] so
/// per-ingredient portion adjustments stay reflected everywhere.
class PendingMealAnalysis {
  const PendingMealAnalysis({
    required this.storagePath,
    required this.mealName,
    required this.healthScore,
    required this.items,
    required this.mealType,
  });

  /// `null` only for a re-logged meal whose original had no photo.
  final String? storagePath;
  final String mealName;
  final int healthScore;
  final List<MealAnalysisItem> items;
  final MealType mealType;

  int get totalCalories =>
      items.fold(0.0, (sum, item) => sum + item.adjustedCalories).round();
  int get totalProtein =>
      items.fold(0.0, (sum, item) => sum + item.adjustedProteinG).round();
  int get totalCarbs =>
      items.fold(0.0, (sum, item) => sum + item.adjustedCarbsG).round();
  int get totalFats =>
      items.fold(0.0, (sum, item) => sum + item.adjustedFatsG).round();

  PendingMealAnalysis copyWith({String? mealName, MealType? mealType}) {
    return PendingMealAnalysis(
      storagePath: storagePath,
      mealName: mealName ?? this.mealName,
      healthScore: healthScore,
      items: items,
      mealType: mealType ?? this.mealType,
    );
  }

  PendingMealAnalysis withItemPortion(int index, double portion) {
    final updated = [...items];
    updated[index] = updated[index].copyWith(portion: portion);
    return PendingMealAnalysis(
      storagePath: storagePath,
      mealName: mealName,
      healthScore: healthScore,
      items: updated,
      mealType: mealType,
    );
  }

  /// Removes an ingredient entirely — used when Gemini detects something
  /// that isn't actually part of the meal.
  PendingMealAnalysis withItemRemoved(int index) {
    final updated = [...items]..removeAt(index);
    return PendingMealAnalysis(
      storagePath: storagePath,
      mealName: mealName,
      healthScore: healthScore,
      items: updated,
      mealType: mealType,
    );
  }

  /// Puts a previously-removed ingredient back at [index] — undoes
  /// [withItemRemoved].
  PendingMealAnalysis withItemInserted(int index, MealAnalysisItem item) {
    final updated = [...items]..insert(index.clamp(0, items.length), item);
    return PendingMealAnalysis(
      storagePath: storagePath,
      mealName: mealName,
      healthScore: healthScore,
      items: updated,
      mealType: mealType,
    );
  }
}

/// The raw outcome of analyzing a photo, before it's paired with the
/// storage path it was uploaded to (see [PendingMealAnalysis]).
class MealAnalysisResult {
  const MealAnalysisResult({
    required this.mealName,
    required this.healthScore,
    required this.items,
  });

  final String mealName;
  final int healthScore;
  final List<MealAnalysisItem> items;
}
