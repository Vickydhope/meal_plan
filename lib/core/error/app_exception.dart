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

/// Thrown when sign-up/sign-in/sign-out fails, with [message] already
/// mapped to something safe to show a user (see
/// `SupabaseAuthRepository._mapAuthError`). Named `*Failure*` rather than
/// `AuthException` to avoid colliding with `package:supabase_flutter`'s own
/// `AuthException` type, which callers also have in scope.
class AuthFailureException extends AppException {
  const AuthFailureException(super.message);
}
