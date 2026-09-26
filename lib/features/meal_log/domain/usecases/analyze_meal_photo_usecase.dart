import '../entities/meal_analysis_stream_event.dart';
import '../entities/meal_type.dart';
import '../entities/pending_meal_analysis.dart';
import '../repositories/food_analysis_repository.dart';
import '../repositories/image_repository.dart';

/// Compresses/uploads a captured photo (or takes a typed description, see
/// [fromDescription]) and streams its nutrition analysis
/// as it's detected, ending in a [PendingAnalysisReady] event carrying a
/// [PendingMealAnalysis] ready for user review. This is one coherent
/// business transaction even though it spans two repositories.
class AnalyzeMealPhotoUseCase {
  AnalyzeMealPhotoUseCase({
    required ImageRepository imageRepository,
    required FoodAnalysisRepository foodAnalysisRepository,
  }) : _imageRepository = imageRepository,
       _foodAnalysisRepository = foodAnalysisRepository;

  final ImageRepository _imageRepository;
  final FoodAnalysisRepository _foodAnalysisRepository;

  Stream<MealAnalysisStreamEvent> call({
    required String userId,
    required String imagePath,
    MealType? mealType,
  }) async* {
    final bytes = await _imageRepository.compressImage(imagePath);
    final storagePath = await _imageRepository.uploadImage(
      userId: userId,
      bytes: bytes,
    );
    final resolvedMealType = mealType ?? MealType.forTime(DateTime.now());
    yield UploadCompleted(storagePath);

    await for (final event in _foodAnalysisRepository.analyze(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    )) {
      if (event is AnalysisCompleted) {
        yield PendingAnalysisReady(
          PendingMealAnalysis(
            storagePath: storagePath,
            mealName: event.result.mealName,
            healthScore: event.result.healthScore,
            items: event.result.items,
            mealType: resolvedMealType,
          ),
        );
      } else {
        yield event;
      }
    }
  }

  /// Streams the nutrition analysis of a typed [description] of the meal,
  /// like [call] but with no photo to compress or upload — the resulting
  /// [PendingMealAnalysis] has no storage path.
  Stream<MealAnalysisStreamEvent> fromDescription({
    required String description,
    MealType? mealType,
  }) async* {
    final resolvedMealType = mealType ?? MealType.forTime(DateTime.now());
    await for (final event in _foodAnalysisRepository.analyzeDescription(
      description,
    )) {
      if (event is AnalysisCompleted) {
        yield PendingAnalysisReady(
          PendingMealAnalysis(
            storagePath: null,
            mealName: event.result.mealName,
            healthScore: event.result.healthScore,
            items: event.result.items,
            mealType: resolvedMealType,
          ),
        );
      } else {
        yield event;
      }
    }
  }

  /// Aborts the in-flight [call]/[fromDescription] request, if any — see
  /// [FoodAnalysisRepository.cancelInFlight].
  void cancelInFlight() => _foodAnalysisRepository.cancelInFlight();
}
