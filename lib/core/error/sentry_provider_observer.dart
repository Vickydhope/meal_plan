import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Reports any provider/notifier that fails to build (throws during
/// creation or a rebuild) to Sentry — e.g. a `NotifierProvider` whose
/// `build()` throws. Errors a notifier already catches internally and
/// surfaces as `state.error` (the normal, user-facing error path used
/// throughout this app) never reach here, since they're handled, not
/// thrown out of the provider.
class SentryProviderObserver extends ProviderObserver {
  const SentryProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) => scope.setTag(
        'provider',
        provider.name ?? provider.runtimeType.toString(),
      ),
    );
  }
}
