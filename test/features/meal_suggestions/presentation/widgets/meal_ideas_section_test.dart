import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_item.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_suggestions/domain/entities/meal_suggestion.dart';
import 'package:meal_plan/features/meal_suggestions/presentation/providers/meal_suggestion_providers.dart';
import 'package:meal_plan/features/meal_suggestions/presentation/widgets/meal_ideas_section.dart';
import 'package:meal_plan/features/profile/presentation/providers/profile_providers.dart';
import 'package:meal_plan/shared/widgets/shimmer_box.dart';

const _ideas = MealIdeas(
  remaining: RemainingDay(
    calories: 900,
    protein: 60,
    carbs: 90,
    fats: 30,
    mealTypes: [MealType.dinner],
  ),
  meals: [
    MealSuggestion(
      mealType: MealType.dinner,
      mealName: 'Dal Rice',
      description: 'Comforting.',
      healthScore: 8,
      items: [
        MealAnalysisItem(
          foodName: 'Dal',
          estimatedWeightG: 200,
          calories: 300,
          proteinG: 18,
          carbsG: 40,
          fatsG: 6,
        ),
      ],
    ),
  ],
);

/// Starts with ideas already generated; [refreshing] puts it in the state
/// MealIdeasNotifier.generate() uses for a refresh.
class _FakeIdeas extends MealIdeasNotifier {
  @override
  MealIdeas? build() => _ideas;

  void refreshing() =>
      state = const AsyncLoading<MealIdeas?>().copyWithPrevious(state);
}

void main() {
  testWidgets('refreshing ideas shows shimmer instead of the old ones', (
    tester,
  ) async {
    final fake = _FakeIdeas();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealIdeasProvider.overrideWith(() => fake),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MealIdeasSection()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Dal Rice'), findsOneWidget);
    expect(find.byType(ShimmerBox), findsNothing);

    fake.refreshing();
    await tester.pump();

    expect(find.text('Dal Rice'), findsNothing);
    expect(find.byType(ShimmerBox), findsWidgets);
    expect(find.text('Planning your meals…'), findsOneWidget);
  });
}
