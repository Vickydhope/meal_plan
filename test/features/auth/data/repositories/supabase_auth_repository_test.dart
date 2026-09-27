import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

void main() {
  late _MockAuth auth;
  late SupabaseAuthRepository repository;

  setUp(() {
    final client = _MockClient();
    auth = _MockAuth();
    when(() => client.auth).thenReturn(auth);
    repository = SupabaseAuthRepository(client);
  });

  Future<void> signIn() =>
      repository.signInWithEmail(email: 'a@b.co', password: 'secret');

  void signInThrows(Object err) => when(
    () => auth.signInWithPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenThrow(err);

  Matcher failsWith(String message) => throwsA(
    isA<AuthFailureException>().having((e) => e.message, 'message', message),
  );

  test('maps known Supabase error codes to friendly copy', () {
    signInThrows(const AuthApiException('raw', code: 'invalid_credentials'));
    expect(signIn(), failsWith('Incorrect email or password.'));
  });

  test('sign up maps an existing account to a log-in hint', () {
    when(
      () => auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthApiException('raw', code: 'user_already_exists'));

    expect(
      repository.signUpWithEmail(email: 'a@b.co', password: 'secret'),
      failsWith(
        'An account with this email already exists. Try logging in instead.',
      ),
    );
  });

  test('unknown codes fall back to the API message', () {
    signInThrows(const AuthApiException('Signups not allowed', code: 'x'));
    expect(signIn(), failsWith('Signups not allowed'));
  });

  test('non-API errors never leak their text', () {
    signInThrows(Exception('SocketException: host lookup failed'));
    expect(signIn(), failsWith('Sign in failed. Try again.'));
  });
}
