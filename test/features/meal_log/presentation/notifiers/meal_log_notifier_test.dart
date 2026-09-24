import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/auth/domain/repositories/auth_repository.dart';
import 'package:meal_plan/features/auth/presentation/providers/auth_providers.dart';
import 'package:meal_plan/features/fitness/domain/repositories/fitness_repository.dart';
import 'package:meal_plan/features/fitness/presentation/providers/fitness_providers.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_item.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_analysis_stream_event.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_log.dart';
import 'package:meal_plan/features/meal_log/domain/entities/meal_type.dart';
import 'package:meal_plan/features/meal_log/domain/entities/pending_meal_analysis.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/food_analysis_repository.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/image_repository.dart';
import 'package:meal_plan/features/meal_log/domain/repositories/meal_log_repository.dart';
import 'package:meal_plan/features/meal_log/presentation/providers/meal_log_providers.dart';
import 'package:meal_plan/features/profile/domain/repositories/profile_repository.dart';
import 'package:meal_plan/features/profile/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockMealLogRepository extends Mock implements MealLogRepository {}

class _MockImageRepository extends Mock implements ImageRepository {}

class _MockFoodAnalysisRepository extends Mock
    implements FoodAnalysisRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFitnessRepository extends Mock implements FitnessRepository {}

const _item = MealAnalysisItem(
  foodName: 'Rice',
  estimatedWeightG: 100,
  calories: 130,
  proteinG: 3,
  carbsG: 28,
  fatsG: 0,
);

MealLog _log(String id) => MealLog(
  id: id,
  userId: 'user-1',
  imageUrl: 'user-1/1.jpg',
  mealName: 'Rice Bowl',
  totalCalories: 130,
  totalProtein: 3,
  totalCarbs: 28,
  totalFats: 0,
  healthScore: 6,
  createdAt: DateTime.now().toUtc(),
  mealType: MealType.lunch,
  items: const [_item],
);

void main() {
  late _MockAuthRepository auth;
  late _MockMealLogRepository mealLogs;
  late _MockImageRepository images;
  late _MockFoodAnalysisRepository analysis;
  late _MockFitnessRepository fitness;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(DateTime(0));
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      const PendingMealAnalysis(
        storagePath: '',
        mealName: '',
        healthScore: 0,
        items: [],
        mealType: MealType.snack,
      ),
    );
  });

  setUp(() {
    auth = _MockAuthRepository();
    mealLogs = _MockMealLogRepository();
    images = _MockImageRepository();
    analysis = _MockFoodAnalysisRepository();
    final profiles = _MockProfileRepository();
    fitness = _MockFitnessRepository();
    when(() => fitness.isMealWriteBackEnabled()).thenAnswer((_) async => false);

    when(() => auth.currentUserId).thenReturn('user-1');
    when(
      () => mealLogs.fetchLogsForDate(
        userId: any(named: 'userId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => []);
    when(() => profiles.fetchProfile(any())).thenAnswer((_) async => null);

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        mealLogRepositoryProvider.overrideWithValue(mealLogs),
        imageRepositoryProvider.overrideWithValue(images),
        foodAnalysisRepositoryProvider.overrideWithValue(analysis),
        profileRepositoryProvider.overrideWithValue(profiles),
        fitnessRepositoryProvider.overrideWithValue(fitness),
      ],
    );
    addTearDown(container.dispose);
  });

  void stubSuccessfulAnalysis() {
    when(() => images.compressImage(any()))
        .thenAnswer((_) async => Uint8List(1));
    when(
      () => images.uploadImage(
        userId: any(named: 'userId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => 'user-1/1.jpg');
    when(
      () => analysis.analyze(
        imageBytes: any(named: 'imageBytes'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable([
        const MealNameDetected('Rice Bowl'),
        const ItemDetected(_item),
        const AnalysisCompleted(
          MealAnalysisResult(
            mealName: 'Rice Bowl',
            healthScore: 6,
            items: [_item],
          ),
        ),
      ]),
    );
  }

  test(
    'analyzeCapturedPhoto stages the result as a pending analysis',
    () async {
      stubSuccessfulAnalysis();
      final notifier = container.read(mealLogProvider.notifier);

      await notifier.analyzeCapturedPhoto('/tmp/photo.jpg');

      final state = container.read(mealLogProvider);
      expect(state.pendingAnalysis?.mealName, 'Rice Bowl');
      expect(state.pendingAnalysis?.storagePath, 'user-1/1.jpg');
      expect(state.pendingAnalysis?.items, [_item]);
      expect(state.isStreaming, isFalse);
      expect(state.isProcessing, isFalse);
      expect(state.streamingItems, isEmpty);
      expect(state.error, isNull);
    },
  );

  test('analyzeCapturedPhoto shows a safe message when upload fails', () async {
    when(() => images.compressImage(any()))
        .thenAnswer((_) async => Uint8List(1));
    when(
      () => images.uploadImage(
        userId: any(named: 'userId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenThrow(const ImageProcessingException('Failed to upload: 500 raw'));

    await container
        .read(mealLogProvider.notifier)
        .analyzeCapturedPhoto('/tmp/photo.jpg');

    final state = container.read(mealLogProvider);
    expect(state.error, isNotNull);
    expect(state.error, isNot(contains('raw')));
    expect(state.isProcessing, isFalse);
    expect(state.isStreaming, isFalse);
  });

  test('analyzeCapturedPhoto requires a signed-in user', () async {
    when(() => auth.currentUserId).thenReturn(null);

    await container
        .read(mealLogProvider.notifier)
        .analyzeCapturedPhoto('/tmp/photo.jpg');

    expect(
      container.read(mealLogProvider).error,
      const NotSignedInException().message,
    );
    verifyNever(() => images.compressImage(any()));
  });

  test('confirmMealLog prepends the saved log and clears the pending '
      'analysis', () async {
    stubSuccessfulAnalysis();
    final saved = _log('log-1');
    when(
      () => mealLogs.saveMealLog(
        userId: any(named: 'userId'),
        analysis: any(named: 'analysis'),
      ),
    ).thenAnswer((_) async => saved);
    final notifier = container.read(mealLogProvider.notifier);
    await notifier.analyzeCapturedPhoto('/tmp/photo.jpg');

    await notifier.confirmMealLog();

    final state = container.read(mealLogProvider);
    expect(state.logs, [saved]);
    expect(state.pendingAnalysis, isNull);
    expect(state.isProcessing, isFalse);
  });

  test('deleteMealLog puts the log back and shows a safe message when the '
      'backend call fails', () async {
    final log = _log('log-1');
    when(
      () => mealLogs.fetchLogsForDate(
        userId: any(named: 'userId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => [log]);
    when(() => mealLogs.deleteMealLog('log-1')).thenThrow(
      const MealLogPersistenceException('PostgrestException(code: 42501)'),
    );
    final notifier = container.read(mealLogProvider.notifier);
    await notifier.fetchLogsForSelectedDate();

    final index = await notifier.deleteMealLog(log);

    final state = container.read(mealLogProvider);
    expect(index, isNull);
    expect(state.logs, [log]);
    expect(state.error, isNot(contains('Postgrest')));
  });

  test('confirmMealLog mirrors the saved meal into Health when enabled, '
      'and a Health failure does not surface as a meal error', () async {
    stubSuccessfulAnalysis();
    final saved = _log('log-1');
    when(
      () => mealLogs.saveMealLog(
        userId: any(named: 'userId'),
        analysis: any(named: 'analysis'),
      ),
    ).thenAnswer((_) async => saved);
    when(() => fitness.isMealWriteBackEnabled()).thenAnswer((_) async => true);
    when(() => fitness.deleteMeal(any())).thenAnswer((_) async {});
    when(() => fitness.writeMeal(saved))
        .thenThrow(const HealthStoreUnavailableException('store down'));
    final notifier = container.read(mealLogProvider.notifier);
    await notifier.analyzeCapturedPhoto('/tmp/photo.jpg');

    await notifier.confirmMealLog();
    await pumpEventQueue();

    verify(() => fitness.writeMeal(saved)).called(1);
    final state = container.read(mealLogProvider);
    expect(state.logs, [saved]);
    expect(state.error, isNull);
  });
}
