import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/profile/domain/repositories/avatar_repository.dart';
import 'package:meal_plan/features/profile/domain/repositories/profile_repository.dart';
import 'package:meal_plan/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockAvatarRepository extends Mock implements AvatarRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockAvatarRepository avatarRepository;
  late _MockProfileRepository profileRepository;
  late UploadAvatarUseCase useCase;

  final bytes = Uint8List.fromList([1, 2, 3]);

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    avatarRepository = _MockAvatarRepository();
    profileRepository = _MockProfileRepository();
    useCase = UploadAvatarUseCase(
      avatarRepository: avatarRepository,
      profileRepository: profileRepository,
    );

    when(() => avatarRepository.compressImage(any()))
        .thenAnswer((_) async => bytes);
    when(
      () => avatarRepository.uploadAvatar(
        userId: any(named: 'userId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => 'user-1/123.jpg');
    when(() => avatarRepository.publicUrlFor(any()))
        .thenReturn('https://example.com/user-1/123.jpg');
    when(() => avatarRepository.deleteAvatar(any())).thenAnswer((_) async {});
    when(
      () => profileRepository.updateProfile(
        userId: any(named: 'userId'),
        avatarPath: any(named: 'avatarPath'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'compresses, uploads, saves the new path, and returns the public url',
    () async {
      final url = await useCase(userId: 'user-1', imagePath: '/tmp/photo.jpg');

      expect(url, 'https://example.com/user-1/123.jpg');
      verify(() => avatarRepository.compressImage('/tmp/photo.jpg')).called(1);
      verify(
        () => avatarRepository.uploadAvatar(userId: 'user-1', bytes: bytes),
      ).called(1);
      verify(
        () => profileRepository.updateProfile(
          userId: 'user-1',
          avatarPath: 'user-1/123.jpg',
        ),
      ).called(1);
    },
  );

  test('deletes the previous avatar when one is given', () async {
    await useCase(
      userId: 'user-1',
      imagePath: '/tmp/photo.jpg',
      previousAvatarPath: 'user-1/old.jpg',
    );

    verify(() => avatarRepository.deleteAvatar('user-1/old.jpg')).called(1);
  });

  test('does not attempt a delete when there is no previous avatar', () async {
    await useCase(userId: 'user-1', imagePath: '/tmp/photo.jpg');

    verifyNever(() => avatarRepository.deleteAvatar(any()));
  });

  test('propagates exceptions from compression', () async {
    when(() => avatarRepository.compressImage(any()))
        .thenThrow(Exception('boom'));

    expect(
      () => useCase(userId: 'user-1', imagePath: '/tmp/photo.jpg'),
      throwsA(isA<Exception>()),
    );
  });

  test('propagates exceptions from the profile update', () async {
    when(
      () => profileRepository.updateProfile(
        userId: any(named: 'userId'),
        avatarPath: any(named: 'avatarPath'),
      ),
    ).thenThrow(Exception('boom'));

    expect(
      () => useCase(userId: 'user-1', imagePath: '/tmp/photo.jpg'),
      throwsA(isA<Exception>()),
    );
  });
}
