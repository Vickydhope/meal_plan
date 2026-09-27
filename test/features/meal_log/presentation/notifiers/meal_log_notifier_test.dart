import 'dart:async';
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
        currentUserProfileProvider.overrideWith((ref) async => null),
        fitnessRepositoryProvider.overrideWithValue(fitness),
      ],
    );
    addTearDown(container.dispose);
    // As in the app, where Home keeps the day's list alive: created up
    // front, so its initial fetch can't land after (and clobber) a save.
    container.read(mealLogProvider);
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
      final notifier = container.read(scanSessionProvider.notifier);

      await notifier.analyzeCapturedPhoto('/tmp/photo.jpg');

      final state = container.read(scanSessionProvider);
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
        .read(scanSessionProvider.notifier)
        .analyzeCapturedPhoto('/tmp/photo.jpg');

    final state = container.read(scanSessionProvider);
    expect(state.error, isNotNull);
    expect(state.error, isNot(contains('raw')));
    expect(state.isProcessing, isFalse);
    expect(state.isStreaming, isFalse);
  });

  test('analyzeCapturedPhoto requires a signed-in user', () async {
    when(() => auth.currentUserId).thenReturn(null);

    await container
        .read(scanSessionProvider.notifier)
        .analyzeCapturedPhoto('/tmp/photo.jpg');

    expect(
      container.read(scanSessionProvider).error,
      const NotSignedInException().message,
    );
    verifyNever(() => images.compressImage(any()));
  });

  test('confirm prepends the saved log to the day and clears the pending '
      'analysis', () async {
    stubSuccessfulAnalysis();
    final saved = _log('log-1');
    when(
      () => mealLogs.saveMealLog(
        userId: any(named: 'userId'),
        analysis: any(named: 'analysis'),
      ),
    ).thenAnswer((_) async => saved);
    final scan = container.read(scanSessionProvider.notifier);
    await scan.analyzeCapturedPhoto('/tmp/photo.jpg');

    expect(await scan.confirm(), isTrue);

    expect(container.read(mealLogProvider).logs, [saved]);
    // Downstream features (reminders, the feed) watch this.
    expect(container.read(mealLogChangesProvider), 1);
    final state = container.read(scanSessionProvider);
    expect(state.pendingAnalysis, isNull);
    expect(state.isProcessing, isFalse);
  });

  test('confirm keeps the pending analysis and reports failure when the '
      'save fails', () async {
    stubSuccessfulAnalysis();
    when(
      () => mealLogs.saveMealLog(
        userId: any(named: 'userId'),
        analysis: any(named: 'analysis'),
      ),
    ).thenThrow(const MealLogPersistenceException('PostgrestException'));
    final scan = container.read(scanSessionProvider.notifier);
    await scan.analyzeCapturedPhoto('/tmp/photo.jpg');

    expect(await scan.confirm(), isFalse);

    expect(container.read(scanSessionProvider).pendingAnalysis, isNotNull);
    expect(container.read(mealLogProvider).logs, isEmpty);
    expect(container.read(mealLogProvider).error, isNotNull);
  });

  test('a save while a fetch is in flight survives the fetch', () async {
    final saved = _log('log-1');
    final staleFetch = Completer<List<MealLog>>();
    var fetches = 0;
    when(
      () => mealLogs.fetchLogsForDate(
        userId: any(named: 'userId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (_) => ++fetches == 1 ? staleFetch.future : Future.value([saved]),
    );
    when(
      () => mealLogs.saveMealLog(
        userId: any(named: 'userId'),
        analysis: any(named: 'analysis'),
      ),
    ).thenAnswer((_) async => saved);
    final notifier = container.read(mealLogProvider.notifier);

    final fetch = notifier.fetchLogsForSelectedDate();
    await notifier.relogMeal(saved);
    staleFetch.complete([]); // Read before the save landed.
    await fetch;

    final state = container.read(mealLogProvider);
    expect(state.logs, [saved]);
    expect(state.isLoadingLogs, isFalse);
  });

  test("a fetch for a day that's no longer selected is ignored", () async {
    final todayFetch = Completer<List<MealLog>>();
    var fetches = 0;
    when(
      () => mealLogs.fetchLogsForDate(
        userId: any(named: 'userId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (_) => ++fetches == 1 ? todayFetch.future : Future.value(<MealLog>[]),
    );
    final notifier = container.read(mealLogProvider.notifier);

    final stale = notifier.fetchLogsForSelectedDate();
    await notifier.selectDate(DateTime.now().subtract(const Duration(days: 1)));
    todayFetch.complete([_log('today')]);
    await stale;

    expect(container.read(mealLogProvider).logs, isEmpty);
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

  test('confirm mirrors the saved meal into Health when enabled, '
      'and a Health failure is surfaced without losing the meal', () async {
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
    final scan = container.read(scanSessionProvider.notifier);
    await scan.analyzeCapturedPhoto('/tmp/photo.jpg');

    await scan.confirm();
    await pumpEventQueue();

    verify(() => fitness.writeMeal(saved)).called(1);
    final state = container.read(mealLogProvider);
    expect(state.logs, [saved]);
    expect(state.error, 'store down');
  });

  test('stopping a description analysis keeps what was detected, with no '
      'photo', () async {
    final events = StreamController<MealAnalysisStreamEvent>();
    when(() => analysis.analyzeDescription(any()))
        .thenAnswer((_) => events.stream);
    // Like the real client: aborting the request ends its stream, which is
    // what lets cancelling the analysis subscription complete.
    when(() => analysis.cancelInFlight()).thenAnswer((_) {
      events.close();
    });
    final notifier = container.read(scanSessionProvider.notifier);

    unawaited(notifier.analyzeDescription('rice bowl'));
    await pumpEventQueue();
    events
      ..add(const MealNameDetected('Rice Bowl'))
      ..add(const ItemDetected(_item));
    await pumpEventQueue();
    await notifier.stopAnalyzing();

    final state = container.read(scanSessionProvider);
    expect(state.error, isNull);
    expect(state.pendingAnalysis?.storagePath, isNull);
    expect(state.pendingAnalysis?.mealName, 'Rice Bowl');
    expect(state.pendingAnalysis?.items, [_item]);
  });
}
