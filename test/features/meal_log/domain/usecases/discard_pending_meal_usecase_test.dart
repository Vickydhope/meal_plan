import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/image_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/discard_pending_meal_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockImageRepository extends Mock implements ImageRepository {}

void main() {
  late _MockImageRepository repository;
  late DiscardPendingMealUseCase useCase;

  setUp(() {
    repository = _MockImageRepository();
    useCase = DiscardPendingMealUseCase(repository);
  });

  test('deletes the image at the given storage path', () async {
    when(() => repository.deleteImage('user-1/1.jpg')).thenAnswer((_) async {});

    await useCase('user-1/1.jpg');

    verify(() => repository.deleteImage('user-1/1.jpg')).called(1);
  });
}
