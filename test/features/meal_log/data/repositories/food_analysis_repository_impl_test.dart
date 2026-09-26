import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/meal_log/data/datasources/food_analysis_remote_data_source.dart';
import 'package:meal_plan/features/meal_log/data/repositories/food_analysis_repository_impl.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_stream_event.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements FoodAnalysisRemoteDataSource {}

void main() {
  late _MockDataSource dataSource;
  late FoodAnalysisRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    dataSource = _MockDataSource();
    repository = FoodAnalysisRepositoryImpl(dataSource);
  });

  void stubStream(Stream<Map<String, dynamic>> stream) {
    when(
      () => dataSource.streamAnalyzeFood(
        imageBytes: any(named: 'imageBytes'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer((_) => stream);
  }

  Stream<MealAnalysisStreamEvent> analyze() =>
      repository.analyze(imageBytes: Uint8List(1), mimeType: 'image/jpeg');

  test('maps raw SSE events to domain events', () async {
    stubStream(
      Stream.fromIterable([
        {'_event': 'meal_name', 'name': 'Rice Bowl'},
        {'_event': 'item', 'food_name': 'Rice', 'calories': 130},
        {
          '_event': 'done',
          'meal_name': 'Rice Bowl',
          'health_score': 6,
          'items': [
            {'food_name': 'Rice', 'calories': 130},
          ],
        },
        {'_event': 'error', 'message': 'No food was detected'},
      ]),
    );

    final events = await analyze().toList();

    expect((events[0] as MealNameDetected).mealName, 'Rice Bowl');
    expect((events[1] as ItemDetected).item.calories, 130);
    expect((events[2] as AnalysisCompleted).result.items, hasLength(1));
    expect((events[3] as AnalysisFailed).message, 'No food was detected');
  });

  test('surfaces the edge function error message as-is', () async {
    stubStream(
      Stream.error(const FoodAnalysisException('Hourly limit reached.')),
    );

    final events = await analyze().toList();

    expect((events.single as AnalysisFailed).message, 'Hourly limit reached.');
  });

  test('hides raw text from unexpected errors', () async {
    stubStream(Stream.error(Exception('SocketException: host lookup')));

    final events = await analyze().toList();

    expect(
      (events.single as AnalysisFailed).message,
      isNot(contains('SocketException')),
    );
  });

  test('analyzeDescription sends the text and maps its events', () async {
    when(() => dataSource.streamAnalyzeFood(text: '2 eggs')).thenAnswer(
      (_) => Stream.fromIterable([
        {'_event': 'meal_name', 'name': 'Eggs'},
      ]),
    );

    final events = await repository.analyzeDescription('2 eggs').toList();

    expect((events.single as MealNameDetected).mealName, 'Eggs');
  });
}
