import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';
import '../../../meal_log/presentation/providers/meal_log_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/meal_suggestion_repository_impl.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../../domain/repositories/meal_suggestion_repository.dart';
import '../../domain/usecases/suggest_meals_usecase.dart';

final mealSuggestionRepositoryProvider = Provider<MealSuggestionRepository>(
  (ref) => MealSuggestionRepositoryImpl(ref.watch(supabaseClientProvider)),
);

final suggestMealsUseCaseProvider = Provider(
  (ref) => SuggestMealsUseCase(ref.watch(mealSuggestionRepositoryProvider)),
);

/// The last generated ideas and the budget they were planned for. A
/// `null` [remaining] means today's goal was already reached.
class MealIdeas {
  const MealIdeas({required this.remaining, required this.meals});

  final RemainingDay? remaining;
  final List<MealSuggestion> meals;
}

/// Meal ideas for the rest of today. Starts empty (`null`) and only calls
/// the AI on [generate], so opening the Plan tab costs nothing. Kept for
/// the session so switching tabs doesn't lose them.
class MealIdeasNotifier extends AsyncNotifier<MealIdeas?> {
  @override
  FutureOr<MealIdeas?> build() {
    ref.watch(authUserIdProvider); // New user, fresh slate.
    return null;
  }

  Future<void> generate() async {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;
    state = const AsyncLoading<MealIdeas?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      // Today's budget as the app shows it (activity-adjusted if enabled),
      // and today's meals fetched fresh — Home may be showing another day.
      final int budget =
          ref.read(todayCalorieBudgetProvider) ??
          ref.read(dailyCalorieTargetProvider);
      final logs = await ref.read(fetchMealLogsUseCaseProvider)(
        userId: userId,
        date: DateTime.now(),
      );
      final remaining = SuggestMealsUseCase.remainingDay(
        calorieBudget: budget,
        todaysLogs: logs,
        now: DateTime.now(),
      );
      if (remaining == null) return const MealIdeas(remaining: null, meals: []);
      final meals = await ref.read(suggestMealsUseCaseProvider)(remaining);
      return MealIdeas(remaining: remaining, meals: meals);
    });
  }

  /// Drops [meal] once it's been logged from the review screen.
  void markLogged(MealSuggestion meal) {
    final ideas = state.value;
    if (ideas == null) return;
    state = AsyncData(
      MealIdeas(
        remaining: ideas.remaining,
        meals: [...ideas.meals]..remove(meal),
      ),
    );
  }
}

final mealIdeasProvider = AsyncNotifierProvider<MealIdeasNotifier, MealIdeas?>(
  MealIdeasNotifier.new,
);
