import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_item.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_stream_event.dart';
import 'package:meal_plan/features/meal_log/domain/entities/pending_meal_analysis.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/food_analysis_repository.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/image_repository.dart';
import 'package:meal_plan/features/meal_log/domain/usecases/analyze_meal_photo_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockImageRepository extends Mock implements ImageRepository {}

class _MockFoodAnalysisRepository extends Mock implements FoodAnalysisRepository {}

void main() {
  late _MockImageRepository imageRepository;
  late _MockFoodAnalysisRepository foodAnalysisRepository;
  late AnalyzeMealPhotoUseCase useCase;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    imageRepository = _MockImageRepository();
    foodAnalysisRepository = _MockFoodAnalysisRepository();
    useCase = AnalyzeMealPhotoUseCase(
      imageRepository: imageRepository,
      foodAnalysisRepository: foodAnalysisRepository,
    );
  });

  test('compresses, uploads, streams progress, and ends with a pending '
      'analysis tagged with the uploaded storage path', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(() => imageRepository.compressImage('photo.jpg'))
        .thenAnswer((_) async => bytes);
    when(() => imageRepository.uploadImage(userId: 'user-1', bytes: bytes))
        .thenAnswer((_) async => 'user-1/123.jpg');

    const item = MealAnalysisItem(
      foodName: 'Chicken',
      estimatedWeightG: 150,
      calories: 250,
      proteinG: 40,
      carbsG: 0,
      fatsG: 8,
    );
    when(() => foodAnalysisRepository.analyze(
          imageBytes: bytes,
          mimeType: 'image/jpeg',
        )).thenAnswer((_) => Stream.fromIterable(const [
          MealNameDetected('Grilled Chicken Bowl'),
          ItemDetected(item),
          AnalysisCompleted(
            MealAnalysisResult(
              mealName: 'Grilled Chicken Bowl',
              healthScore: 8,
              items: [item],
            ),
          ),
        ]));

    final events = await useCase(userId: 'user-1', imagePath: 'photo.jpg')
        .toList();

    expect(events, hasLength(4)); // upload + name + item + ready
    final ready = events.last as PendingAnalysisReady;
    expect(ready.pending.storagePath, 'user-1/123.jpg');
    expect(ready.pending.mealName, 'Grilled Chicken Bowl');
    expect(ready.pending.healthScore, 8);
    expect(ready.pending.items, hasLength(1));
    verify(() => imageRepository.compressImage('photo.jpg')).called(1);
    verify(() => imageRepository.uploadImage(userId: 'user-1', bytes: bytes))
        .called(1);
  });

  test('surfaces a food-analysis failure as an AnalysisFailed event', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(() => imageRepository.compressImage(any()))
        .thenAnswer((_) async => bytes);
    when(() => imageRepository.uploadImage(
          userId: any(named: 'userId'),
          bytes: any(named: 'bytes'),
        )).thenAnswer((_) async => 'user-1/123.jpg');
    when(() => foodAnalysisRepository.analyze(
          imageBytes: any(named: 'imageBytes'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer(
      (_) => Stream.fromIterable(const [AnalysisFailed('boom')]),
    );

    final events = await useCase(userId: 'user-1', imagePath: 'photo.jpg')
        .toList();

    expect(events.last, isA<AnalysisFailed>());
    expect((events.last as AnalysisFailed).message, 'boom');
  });
}
