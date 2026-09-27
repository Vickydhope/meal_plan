import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../../meal_log/data/models/meal_analysis_item_dto.dart';
import '../../../meal_log/domain/entities/meal_type.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../../domain/repositories/meal_suggestion_repository.dart';

/// Calls the `suggest-meals` edge function — one JSON request, so it talks
/// to [SupabaseClient] directly rather than via a datasource class.
class MealSuggestionRepositoryImpl implements MealSuggestionRepository {
  MealSuggestionRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _fallback = "Couldn't get meal ideas. Try again.";

  @override
  Future<List<MealSuggestion>> suggest(RemainingDay remaining) async {
    final Object? data;
    try {
      final response = await _client.functions.invoke(
        'suggest-meals',
        body: {
          'remaining': {
            'calories': remaining.calories,
            'protein': remaining.protein,
            'carbs': remaining.carbs,
            'fats': remaining.fats,
          },
          'mealTypes': [for (final t in remaining.mealTypes) t.dbValue],
        },
      );
      data = response.data;
    } on FunctionException catch (err) {
      final details = err.details;
      throw MealSuggestionException(
        details is Map && details['error'] is String
            ? details['error'] as String
            : _fallback,
      );
    } catch (_) {
      throw const MealSuggestionException(_fallback);
    }
    return suggestionsFromJson(data);
  }

  /// Parses the function's `{meals: [...]}` response.
  static List<MealSuggestion> suggestionsFromJson(Object? data) {
    final meals = data is Map ? data['meals'] : null;
    if (meals is! List) throw const MealSuggestionException(_fallback);
    return [
      for (final m in meals.cast<Map<String, dynamic>>())
        MealSuggestion(
          mealType: MealType.fromDbValue(m['meal_type'] as String?),
          mealName: m['meal_name'] as String? ?? 'Meal',
          description: m['description'] as String? ?? '',
          healthScore: (m['health_score'] as num?)?.round() ?? 5,
          items: [
            for (final i in (m['items'] as List).cast<Map<String, dynamic>>())
              MealAnalysisItemDto.fromMap(i).toEntity(),
          ],
        ),
    ];
  }
}
