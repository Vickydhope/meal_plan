import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/auth/domain/repositories/auth_repository.dart';
import 'package:meal_plan/features/auth/presentation/providers/auth_providers.dart';
import 'package:meal_plan/features/fitness/domain/repositories/fitness_repository.dart';
import 'package:meal_plan/features/fitness/presentation/providers/fitness_providers.dart';
import 'package:meal_plan/features/hydration/domain/repositories/water_repository.dart';
import 'package:meal_plan/features/hydration/presentation/providers/water_providers.dart';
import 'package:meal_plan/features/hydration/presentation/widgets/water_card.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockFitnessRepository extends Mock implements FitnessRepository {}

/// Each save stays in flight until the test completes it, so overlapping
/// taps are observable.
class _SlowWaterRepository implements WaterRepository {
  final saved = <int>[];
  final inFlight = <Completer<void>>[];

  @override
  Future<int> fetchWater(String userId, DateTime day) async => 500;

  @override
  Future<void> saveWater(String userId, DateTime day, int ml) {
    saved.add(ml);
    final c = Completer<void>();
    inFlight.add(c);
    return c.future;
  }
}

void main() {
  testWidgets(
    'rapid taps save (and mirror to Health) in order, ending on the latest total',
    (tester) async {
      final auth = _MockAuthRepository();
      when(() => auth.currentUserId).thenReturn('u');
      when(() => auth.userIdChanges).thenAnswer((_) => Stream.value('u'));
      final water = _SlowWaterRepository();
      final fitness = _MockFitnessRepository();
      final healthTotals = <int>[];
      when(fitness.isMealWriteBackEnabled).thenAnswer((_) async => true);
      when(() => fitness.writeWater(any(), any())).thenAnswer((inv) async {
        healthTotals.add(inv.positionalArguments[1] as int);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            waterRepositoryProvider.overrideWithValue(water),
            fitnessRepositoryProvider.overrideWithValue(fitness),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WaterCard(day: DateTime(2026, 9, 28), editable: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('500 / 2500 ml'), findsOneWidget);

      final add = find.byTooltip('Add a glass (250 ml)');
      await tester.tap(add);
      await tester.tap(add);
      await tester.tap(find.byTooltip('Remove a glass'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('1000 / 2500 ml'), findsOneWidget);

      // The first save is in flight; the rest wait behind it.
      expect(water.saved, [750]);
      while (water.inFlight.isNotEmpty) {
        water.inFlight.removeAt(0).complete();
        await tester.pump();
      }
      expect(water.saved.last, 1000);
      // Each save is mirrored to Health right after it, in the same order.
      expect(healthTotals, water.saved);
    },
  );
}
