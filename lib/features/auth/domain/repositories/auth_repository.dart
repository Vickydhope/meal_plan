/// Abstraction over "who is the current user" so feature code depends on
/// this contract instead of reaching into `supabase_flutter` directly.
abstract class AuthRepository {
  /// The signed-in user's id, or `null` if nobody is signed in.
  String? get currentUserId;

  /// The signed-in user's email, or `null` if nobody is signed in.
  String? get currentUserEmail;

  /// Emits whenever the signed-in user changes (sign in, sign out, session
  /// restored on app start), so the presentation layer can route reactively
  /// instead of only checking [currentUserId] once at startup.
  Stream<String?> get userIdChanges;

  /// Creates a new account with [email]/[password]. Throws
  /// `AuthFailureException` (with a message safe to show the user) on
  /// failure — e.g. the email is already registered, or the password is
  /// too weak.
  Future<void> signUpWithEmail({required String email, required String password});

  /// Signs in an existing account. Throws `AuthFailureException` on
  /// failure, e.g. wrong credentials.
  Future<void> signInWithEmail({required String email, required String password});

  /// Signs the current user out.
  Future<void> signOut();
}
