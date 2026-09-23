import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Stream<String?> get userIdChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } on AuthApiException catch (err) {
      throw AuthFailureException(_mapAuthError(err));
    } catch (err) {
      throw AuthFailureException('Sign up failed: $err');
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthApiException catch (err) {
      throw AuthFailureException(_mapAuthError(err));
    } catch (err) {
      throw AuthFailureException('Sign in failed: $err');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthApiException catch (err) {
      throw AuthFailureException(_mapAuthError(err));
    } catch (err) {
      throw AuthFailureException('Sign out failed: $err');
    }
  }

  /// Turns Supabase's raw auth error codes into messages safe to show a
  /// user, instead of leaking SDK/HTTP internals (see plan.md 3.1).
  String _mapAuthError(AuthApiException err) {
    switch (err.code) {
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists. Try logging in instead.';
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'weak_password':
        return 'Password is too weak — use at least 6 characters.';
      case 'email_not_confirmed':
        return 'Please confirm your email before logging in.';
      case 'over_email_send_rate_limit':
        return 'Too many attempts — please wait a moment and try again.';
      default:
        return err.message;
    }
  }
}
