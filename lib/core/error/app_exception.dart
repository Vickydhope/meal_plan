import 'dart:convert';

/// Base type for exceptions raised by repositories. Keeping these distinct
/// from raw plugin/SDK exceptions means the presentation layer can catch a
/// single known family of errors instead of depending on `supabase_flutter`
/// or other infra packages to know what went wrong.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Maps any caught error to text safe to show a user. Repository messages
/// often embed raw SDK errors (e.g. `'Failed to save meal log: $err'`), so
/// only subtypes whose messages are known-safe pass through. The raw error
/// is printed in debug builds so the detail hidden from the user isn't lost.
String userMessageFor(Object err) {
  assert(() {
    // ignore: avoid_print
    print('[AppError] ${err.runtimeType}: $err');
    return true;
  }());
  return _userMessageFor(err);
}

String _userMessageFor(Object err) => switch (err) {
  NotSignedInException(:final message) => message,
  // Built from the edge function's own user-facing `error` text.
  FoodAnalysisException(:final message) => message,
  AskAiException(:final message) => message,
  AuthFailureException(:final message) => message,
  HealthStoreUnavailableException(:final message) => message,
  HealthPermissionDeniedException(:final message) => message,
  NotificationPermissionDeniedException(:final message) => message,
  MealLogPersistenceException() =>
    "Couldn't reach the server. Check your connection and try again.",
  ImageProcessingException() => "Couldn't process that photo. Try again.",
  _ => 'Something went wrong. Please try again.',
};

/// Thrown when an operation requires a signed-in user but none is available.
class NotSignedInException extends AppException {
  const NotSignedInException() : super('Sign in to log a meal');
}

/// Thrown when reading/writing meal logs or profile data fails.
class MealLogPersistenceException extends AppException {
  const MealLogPersistenceException(super.message);
}

/// Thrown when compressing or uploading a photo fails.
class ImageProcessingException extends AppException {
  const ImageProcessingException(super.message);
}

/// Thrown when the food-analysis backend fails or returns something the
/// app can't interpret.
class FoodAnalysisException extends AppException {
  const FoodAnalysisException(super.message);
}

/// Thrown when the `ask-ai` backend fails.
class AskAiException extends AppException {
  const AskAiException(super.message);
}

/// Thrown when the platform health store can't be used (e.g. Health
/// Connect isn't installed on Android).
class HealthStoreUnavailableException extends AppException {
  const HealthStoreUnavailableException(super.message);
}

/// Thrown when the user declines health-store read access.
class HealthPermissionDeniedException extends AppException {
  const HealthPermissionDeniedException([
    super.message = 'Allow access to steps, active energy and weight to sync.',
  ]);
}

/// Thrown when the user declines notification permission for reminders.
class NotificationPermissionDeniedException extends AppException {
  const NotificationPermissionDeniedException([
    super.message = 'Allow notifications in system settings to get reminders.',
  ]);
}

/// The `error` field of an edge function's JSON error body (e.g. the 429
/// rate-limit text), or [fallback] if the body isn't that shape.
String edgeFunctionErrorMessage(String body, {required String fallback}) {
  try {
    final error = (jsonDecode(body) as Map<String, dynamic>)['error'];
    return error is String ? error : fallback;
  } catch (_) {
    return fallback;
  }
}

/// Thrown when sign-up/sign-in/sign-out fails, with [message] already
/// mapped to something safe to show a user (see
/// `SupabaseAuthRepository._mapAuthError`). Named `*Failure*` rather than
/// `AuthException` to avoid colliding with `package:supabase_flutter`'s own
/// `AuthException` type, which callers also have in scope.
class AuthFailureException extends AppException {
  const AuthFailureException(super.message);
}
