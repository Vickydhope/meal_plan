import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/profile/domain/repositories/profile_repository.dart';
import 'package:meal_plan/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository repository;
  late UpdateProfileUseCase useCase;

  setUp(() {
    repository = _MockProfileRepository();
    useCase = UpdateProfileUseCase(repository);
    when(
      () => repository.updateProfile(
        userId: any(named: 'userId'),
        username: any(named: 'username'),
        fullName: any(named: 'fullName'),
        phone: any(named: 'phone'),
        avatarPath: any(named: 'avatarPath'),
      ),
    ).thenAnswer((_) async {});
  });

  test('forwards the given fields to the repository unchanged', () async {
    await useCase(
      userId: 'user-1',
      username: 'vickyd',
      fullName: 'Victoria Doops',
      phone: '+1 (555) 123-4567',
    );

    verify(
      () => repository.updateProfile(
        userId: 'user-1',
        username: 'vickyd',
        fullName: 'Victoria Doops',
        phone: '+1 (555) 123-4567',
        avatarPath: null,
      ),
    ).called(1);
  });

  test('forwards null for fields that were not passed', () async {
    await useCase(userId: 'user-1', username: 'vickyd');

    verify(
      () => repository.updateProfile(
        userId: 'user-1',
        username: 'vickyd',
        fullName: null,
        phone: null,
        avatarPath: null,
      ),
    ).called(1);
  });

  test('propagates exceptions from the repository', () async {
    when(
      () => repository.updateProfile(
        userId: any(named: 'userId'),
        username: any(named: 'username'),
        fullName: any(named: 'fullName'),
        phone: any(named: 'phone'),
        avatarPath: any(named: 'avatarPath'),
      ),
    ).thenThrow(Exception('boom'));

    expect(
      () => useCase(userId: 'user-1', username: 'vickyd'),
      throwsA(isA<Exception>()),
    );
  });
}
