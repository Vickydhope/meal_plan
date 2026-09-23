import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/image_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/get_signed_image_url_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockImageRepository extends Mock implements ImageRepository {}

void main() {
  late _MockImageRepository repository;
  late GetSignedImageUrlUseCase useCase;

  setUp(() {
    repository = _MockImageRepository();
    useCase = GetSignedImageUrlUseCase(repository);
  });

  test('requests a signed URL with the default expiry', () async {
    when(() => repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 3600))
        .thenAnswer((_) async => 'https://signed.example/1.jpg');

    final result = await useCase('user-1/1.jpg');

    expect(result, 'https://signed.example/1.jpg');
    verify(() =>
            repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 3600))
        .called(1);
  });

  test('forwards a custom expiry to the repository', () async {
    when(() => repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 60))
        .thenAnswer((_) async => 'https://signed.example/1.jpg');

    await useCase('user-1/1.jpg', expiresInSeconds: 60);

    verify(() => repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 60))
        .called(1);
  });

  test('caches a signed URL and reuses it on the next call for the same path',
      () async {
    when(() => repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 3600))
        .thenAnswer((_) async => 'https://signed.example/1.jpg');

    final first = await useCase('user-1/1.jpg');
    final second = await useCase('user-1/1.jpg');

    expect(first, 'https://signed.example/1.jpg');
    expect(second, 'https://signed.example/1.jpg');
    verify(() =>
            repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 3600))
        .called(1);
  });

  test('re-fetches once the cached URL is stale', () async {
    var now = DateTime(2026, 1, 1, 12);
    final clockedUseCase =
        GetSignedImageUrlUseCase(repository, now: () => now);

    when(() => repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 3600))
        .thenAnswer((_) async => 'https://signed.example/first.jpg');
    await clockedUseCase('user-1/1.jpg');

    // Past the 3600s TTL minus the 30s stale buffer.
    now = now.add(const Duration(seconds: 3600 - 30 + 1));
    when(() => repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 3600))
        .thenAnswer((_) async => 'https://signed.example/second.jpg');
    final result = await clockedUseCase('user-1/1.jpg');

    expect(result, 'https://signed.example/second.jpg');
    verify(() =>
            repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 3600))
        .called(2);
  });

  test('caches independently per storage path', () async {
    when(() => repository.getSignedUrl('user-1/1.jpg', expiresInSeconds: 3600))
        .thenAnswer((_) async => 'https://signed.example/1.jpg');
    when(() => repository.getSignedUrl('user-1/2.jpg', expiresInSeconds: 3600))
        .thenAnswer((_) async => 'https://signed.example/2.jpg');

    final first = await useCase('user-1/1.jpg');
    final second = await useCase('user-1/2.jpg');

    expect(first, 'https://signed.example/1.jpg');
    expect(second, 'https://signed.example/2.jpg');
  });
}
