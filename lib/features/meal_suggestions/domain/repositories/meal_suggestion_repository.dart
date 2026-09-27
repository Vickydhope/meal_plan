import '../entities/meal_suggestion.dart';

abstract class MealSuggestionRepository {
  /// One suggested meal per [RemainingDay.mealTypes], together fitting the
  /// remaining budget and the user's saved dietary preferences.
  Future<List<MealSuggestion>> suggest(RemainingDay remaining);
}
