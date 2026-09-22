import 'dart:typed_data';

import '../../domain/entities/meal_analysis_stream_event.dart';
import '../../domain/repositories/food_analysis_repository.dart';
import '../datasources/food_analysis_remote_data_source.dart';
import '../models/meal_analysis_item_dto.dart';
import '../models/meal_analysis_result_dto.dart';

class FoodAnalysisRepositoryImpl implements FoodAnalysisRepository {
  FoodAnalysisRepositoryImpl(this._dataSource);

  final FoodAnalysisRemoteDataSource _dataSource;

  @override
  Stream<MealAnalysisStreamEvent> analyze({
    required Uint8List imageBytes,
    required String mimeType,
  }) async* {
    try {
      await for (final raw in _dataSource.streamAnalyzeFood(
        imageBytes: imageBytes,
        mimeType: mimeType,
      )) {
        switch (raw['_event']) {
          case 'meal_name':
            yield MealNameDetected(raw['name'] as String? ?? '');
          case 'item':
            yield ItemDetected(MealAnalysisItemDto.fromMap(raw).toEntity());
          case 'done':
            yield AnalysisCompleted(
              MealAnalysisResultDto.fromMap(raw).toEntity(),
            );
          case 'error':
            yield AnalysisFailed(
              raw['message'] as String? ?? 'Analysis failed',
            );
        }
      }
    } catch (err) {
      yield AnalysisFailed('Failed to analyze meal photo: $err');
    }
  }

  @override
  void cancelInFlight() => _dataSource.cancelInFlight();
}
