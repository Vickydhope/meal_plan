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
}
