import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';

void main() {
  group('userMessageFor', () {
    test('passes through messages built for users', () {
      expect(
        userMessageFor(const FoodAnalysisException('Hourly limit hit')),
        'Hourly limit hit',
      );
      expect(
        userMessageFor(const NotSignedInException()),
        'Sign in to log a meal',
      );
    });

    test('hides raw SDK text embedded in persistence/image errors', () {
      const raw = 'Failed to save meal log: PostgrestException(code: 42501)';
      final message = userMessageFor(const MealLogPersistenceException(raw));
      expect(message, isNot(contains('Postgrest')));
      expect(
        userMessageFor(const ImageProcessingException('upload: 500')),
        isNot(contains('500')),
      );
    });

    test('falls back to a generic message for unknown errors', () {
      expect(
        userMessageFor(Exception('SocketException: host lookup')),
        'Something went wrong. Please try again.',
      );
    });
  });

  group('edgeFunctionErrorMessage', () {
    test('reads the error field from a JSON body', () {
      expect(
        edgeFunctionErrorMessage('{"error":"Too many"}', fallback: 'x'),
        'Too many',
      );
    });

    test('falls back on non-JSON or missing error field', () {
      expect(edgeFunctionErrorMessage('<html>', fallback: 'x'), 'x');
      expect(edgeFunctionErrorMessage('{"code":401}', fallback: 'x'), 'x');
      expect(edgeFunctionErrorMessage('[1]', fallback: 'x'), 'x');
    });
  });
}
