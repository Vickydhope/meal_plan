import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/app_shell/presentation/screens/app_shell.dart';

void main() {
  Widget container(int index) => Directionality(
    textDirection: TextDirection.ltr,
    child: AnimatedBranchContainer(
      currentIndex: index,
      children: const [Text('home'), Text('plan')],
    ),
  );

  double opacityOf(WidgetTester tester, String label) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('switching back hides the previously active branch', (
    tester,
  ) async {
    await tester.pumpWidget(container(1));
    await tester.pumpWidget(container(0));
    await tester.pumpAndSettle();

    expect(opacityOf(tester, 'home'), 1);
    expect(opacityOf(tester, 'plan'), 0);
    // The outgoing fade must actually run, not freeze at full opacity.
    final planFade = tester.widget<FadeTransition>(
      find.ancestor(
        of: find.text('plan'),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(planFade.opacity.value, 0);
  });
}
