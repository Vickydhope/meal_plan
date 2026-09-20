import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meal_plan/shared/widgets/calorie_ring.dart';

void main() {
  testWidgets('CalorieRing shows consumed and target calories', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: CalorieRing(consumed: 1050, target: 2158)),
      ),
    );

    expect(find.text('1050'), findsOneWidget);
    expect(find.text('of 2158 kcal'), findsOneWidget);
  });
}
