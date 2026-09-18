class MealLog {
  MealLog({
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
  });

  factory MealLog.fromMap(Map<String, dynamic> map) {
    return MealLog(
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
}

/// A single ingredient detected by Gemini, with a user-adjustable portion
/// multiplier (1.0 = the estimated portion as photographed).
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

  factory MealAnalysisItem.fromMap(Map<String, dynamic> map) {
    return MealAnalysisItem(
      foodName: map['food_name'] as String? ?? 'Unknown item',
      estimatedWeightG: (map['estimated_weight_g'] as num?)?.toDouble() ?? 0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toDouble() ?? 0,
      fatsG: (map['fats_g'] as num?)?.toDouble() ?? 0,
    );
  }

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

  Map<String, dynamic> toMap() => {
        'food_name': foodName,
        'estimated_weight_g': estimatedWeightG,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fats_g': fatsG,
        'portion': portion,
      };

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

/// A meal that has been analyzed and uploaded but not yet confirmed/saved.
/// The meal name is directly editable; totals are derived from [items] so
/// per-ingredient portion adjustments stay reflected everywhere.
class PendingMealAnalysis {
  const PendingMealAnalysis({
    required this.storagePath,
    required this.mealName,
    required this.healthScore,
    required this.items,
  });

  factory PendingMealAnalysis.fromGeminiResponse({
    required String storagePath,
    required Map<String, dynamic> data,
  }) {
    final items = ((data['items'] as List?) ?? const [])
        .map((item) => MealAnalysisItem.fromMap(item as Map<String, dynamic>))
        .toList();

    return PendingMealAnalysis(
      storagePath: storagePath,
      mealName: data['meal_name'] as String? ?? 'Meal',
      healthScore: (data['health_score'] as num?)?.round() ?? 5,
      items: items,
    );
  }

  final String storagePath;
  final String mealName;
  final int healthScore;
  final List<MealAnalysisItem> items;

  int get totalCalories =>
      items.fold(0.0, (sum, item) => sum + item.adjustedCalories).round();
  int get totalProtein =>
      items.fold(0.0, (sum, item) => sum + item.adjustedProteinG).round();
  int get totalCarbs =>
      items.fold(0.0, (sum, item) => sum + item.adjustedCarbsG).round();
  int get totalFats =>
      items.fold(0.0, (sum, item) => sum + item.adjustedFatsG).round();

  PendingMealAnalysis copyWith({String? mealName}) {
    return PendingMealAnalysis(
      storagePath: storagePath,
      mealName: mealName ?? this.mealName,
      healthScore: healthScore,
      items: items,
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
    );
  }
}

class MealLogState {
  const MealLogState({
    this.logs = const [],
    this.dailyTarget = 2000,
    this.username,
    this.selectedDate,
    this.isProcessing = false,
    this.pendingAnalysis,
    this.error,
  });

  final List<MealLog> logs;
  final int dailyTarget;
  final String? username;
  final DateTime? selectedDate;
  final bool isProcessing;
  final PendingMealAnalysis? pendingAnalysis;
  final String? error;

  int get totalCaloriesToday =>
      logs.fold(0, (sum, log) => sum + log.totalCalories);
  int get totalProteinToday =>
      logs.fold(0, (sum, log) => sum + log.totalProtein);
  int get totalCarbsToday =>
      logs.fold(0, (sum, log) => sum + log.totalCarbs);
  int get totalFatsToday => logs.fold(0, (sum, log) => sum + log.totalFats);

  MealLogState copyWith({
    List<MealLog>? logs,
    int? dailyTarget,
    String? username,
    DateTime? selectedDate,
    bool? isProcessing,
    PendingMealAnalysis? pendingAnalysis,
    bool clearPendingAnalysis = false,
    String? error,
    bool clearError = false,
  }) {
    return MealLogState(
      logs: logs ?? this.logs,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      username: username ?? this.username,
      selectedDate: selectedDate ?? this.selectedDate,
      isProcessing: isProcessing ?? this.isProcessing,
      pendingAnalysis: clearPendingAnalysis
          ? null
          : (pendingAnalysis ?? this.pendingAnalysis),
      error: clearError ? null : (error ?? this.error),
    );
  }
}
