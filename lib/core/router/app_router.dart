import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_shell/presentation/screens/app_shell.dart';
import '../../features/ask_ai/presentation/screens/ask_ai_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/meal_log/domain/entities/meal_type.dart';
import '../../features/meal_log/presentation/screens/camera_scan_screen.dart';
import '../../features/meal_log/presentation/screens/home_screen.dart';
import '../../features/meal_log/presentation/screens/plan_screen.dart';
import '../../features/meal_log/presentation/screens/scan_result_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'app_route.dart';
import 'auth_loading_screen.dart';
import 'router_refresh_notifier.dart';

/// Builds the app's [GoRouter], gating access to onboarding/the main shell
/// based on auth + profile state — replicates the three-way branch that
/// `_AuthGate` used to implement with a `StreamBuilder`/`AsyncValue.when`.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoute.login.path,
    refreshListenable: ref.watch(routerRefreshNotifierProvider),
    redirect: (context, state) {
      final onAuthScreen = state.matchedLocation == AppRoute.login.path ||
          state.matchedLocation == AppRoute.signup.path;

      final userIdAsync = ref.read(authUserIdProvider);
      final userId = userIdAsync.valueOrNull;
      if (userIdAsync.isLoading || userId == null) {
        return onAuthScreen ? null : AppRoute.login.path;
      }

      final profileAsync = ref.read(currentUserProfileProvider);
      return profileAsync.when(
        loading: () => state.matchedLocation == AppRoute.authLoading.path
            ? null
            : AppRoute.authLoading.path,
        error: (_, _) => state.matchedLocation == AppRoute.authLoading.path
            ? null
            : AppRoute.authLoading.path,
        data: (profile) {
          final onboarded = profile?.hasCompletedOnboarding ?? false;
          if (!onboarded) {
            return state.matchedLocation == AppRoute.onboarding.path
                ? null
                : AppRoute.onboarding.path;
          }
          final atGateRoute = onAuthScreen ||
              state.matchedLocation == AppRoute.onboarding.path ||
              state.matchedLocation == AppRoute.authLoading.path;
          return atGateRoute ? AppRoute.home.path : null;
        },
      );
    },
    routes: [
      GoRoute(
        name: AppRoute.login.name,
        path: AppRoute.login.path,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        name: AppRoute.signup.name,
        path: AppRoute.signup.path,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        name: AppRoute.onboarding.name,
        path: AppRoute.onboarding.path,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: AppRoute.authLoading.name,
        path: AppRoute.authLoading.path,
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoute.home.name,
                path: AppRoute.home.path,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoute.askAi.name,
                path: AppRoute.askAi.path,
                builder: (context, state) => const AskAiScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoute.plan.name,
                path: AppRoute.plan.path,
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
        ],
      ),
      // Top-level siblings of the shell route, not nested in a branch, so
      // they push onto the root Navigator above the shell — preserving the
      // FAB<->CameraScanScreen Hero and today's push-over-the-shell
      // semantics.
      GoRoute(
        name: AppRoute.cameraScan.name,
        path: AppRoute.cameraScan.path,
        builder: (context, state) =>
            CameraScanScreen(initialMealType: state.extra as MealType?),
      ),
      GoRoute(
        name: AppRoute.scanResult.name,
        path: AppRoute.scanResult.path,
        builder: (context, state) =>
            ScanResultScreen(args: state.extra! as ScanResultArgs),
      ),
      GoRoute(
        name: AppRoute.settings.name,
        path: AppRoute.settings.path,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        name: AppRoute.notifications.name,
        path: AppRoute.notifications.path,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        name: AppRoute.profile.name,
        path: AppRoute.profile.path,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
