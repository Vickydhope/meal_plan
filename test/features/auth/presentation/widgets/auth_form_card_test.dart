import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/auth/presentation/widgets/auth_form_card.dart';

void main() {
  Future<bool> validate(
    WidgetTester tester, {
    required String password,
    int? minPasswordLength,
  }) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthFormCard(
          formKey: formKey,
          subtitle: '',
          emailController: TextEditingController(text: 'a@b.co'),
          passwordController: TextEditingController(text: password),
          submitLabel: 'Go',
          submitting: false,
          onSubmit: () {},
          footer: const SizedBox(),
          minPasswordLength: minPasswordLength,
        ),
      ),
    );
    final valid = formKey.currentState!.validate();
    await tester.pump();
    return valid;
  }

  testWidgets('sign up rejects passwords under the minimum', (tester) async {
    expect(
      await validate(tester, password: '1234567', minPasswordLength: 8),
      isFalse,
    );
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(
      await validate(tester, password: '12345678', minPasswordLength: 8),
      isTrue,
    );
  });

  testWidgets('log in accepts short existing passwords, not empty ones', (
    tester,
  ) async {
    expect(await validate(tester, password: '123456'), isTrue);
    expect(await validate(tester, password: ''), isFalse);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('password visibility toggles', (tester) async {
    await validate(tester, password: 'secret');
    bool obscured() =>
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(obscured(), isTrue);
  });
}
