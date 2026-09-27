import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/app/router/app_router.dart';
import 'package:meal_plan/core/router/app_route.dart';
import 'package:meal_plan/features/auth/presentation/providers/auth_providers.dart';
import 'package:meal_plan/features/profile/presentation/providers/profile_providers.dart';

void main() {
  testWidgets('shows auth loading, not login, until session restore emits', (
    tester,
  ) async {
    final auth = StreamController<String?>();
    addTearDown(auth.close);
    final container = ProviderContainer(
      overrides: [
        authUserIdProvider.overrideWith((ref) => auth.stream),
        currentUserProfileProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoute.splash.path,
    );

    auth.add(null); // restore finished: signed out
    await tester.pump();
    await tester.pump();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoute.login.path,
    );
  });

  testWidgets('privacy policy stays reachable while loading and signed out', (
    tester,
  ) async {
    final auth = StreamController<String?>();
    addTearDown(auth.close);
    final container = ProviderContainer(
      overrides: [
        authUserIdProvider.overrideWith((ref) => auth.stream),
        currentUserProfileProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(AppRoute.privacyPolicy.path);
    await tester.pumpAndSettle();
    expect(find.text('Privacy policy'), findsOneWidget);

    auth.add(null); // signed out
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoute.privacyPolicy.path,
    );
  });
}
