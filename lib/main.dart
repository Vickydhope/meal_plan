import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/sentry_config.dart';
import 'core/config/supabase_config.dart';
import 'core/error/sentry_provider_observer.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';

Future<void> main() async {
  // SentryFlutter.init wraps the app in its own zone and installs
  // FlutterError.onError/PlatformDispatcher.onError for us, so every
  // uncaught error in appRunner (including ones before/outside
  // ProviderScope) is captured without a separate runZonedGuarded.
  await SentryFlutter.init(
    (options) {
      options.dsn = SentryConfig.dsn;
      options.environment = SentryConfig.environment;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );

      runApp(
        const ProviderScope(
          observers: [SentryProviderObserver()],
          child: MyApp(),
        ),
      );
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Cravia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        textTheme: GoogleFonts.comfortaaTextTheme(),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryDark,
          contentTextStyle: const TextStyle(color: AppColors.onScrim),
          actionTextColor: AppColors.sage,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
