import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/profile/domain/entities/user_profile.dart';
import 'package:meal_plan/features/profile/domain/repositories/profile_repository.dart';
import 'package:meal_plan/features/profile/domain/usecases/fetch_user_profile_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository repository;
  late FetchUserProfileUseCase useCase;

  setUp(() {
    repository = _MockProfileRepository();
    useCase = FetchUserProfileUseCase(repository);
  });

  test(
    'returns null when the repository has no profile for the user',
    () async {
      when(() => repository.fetchProfile('user-1'))
          .thenAnswer((_) async => null);

      final result = await useCase('user-1');

      expect(result, isNull);
    },
  );

  test('returns the profile from the repository', () async {
    const profile = UserProfile(username: 'vicky', dailyCalorieTarget: 2200);
    when(() => repository.fetchProfile('user-1'))
        .thenAnswer((_) async => profile);

    final result = await useCase('user-1');

    expect(result, profile);
  });
}
