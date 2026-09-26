import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/activity_log_repository_impl.dart';
import '../../data/repositories/health_fitness_repository_impl.dart';
import '../../domain/entities/daily_activity.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../../domain/repositories/fitness_repository.dart';
import '../../domain/usecases/calculate_activity_adjusted_target_usecase.dart';
import '../../domain/usecases/get_today_activity_usecase.dart';
import '../../domain/usecases/remove_meal_from_health_usecase.dart';
import '../../domain/usecases/set_activity_sync_usecase.dart';
import '../../domain/usecases/set_meal_write_back_usecase.dart';
import '../../domain/usecases/sync_weight_from_health_usecase.dart';
import '../../domain/usecases/write_meal_to_health_usecase.dart';

final fitnessRepositoryProvider = Provider<FitnessRepository>(
  (ref) => HealthFitnessRepositoryImpl(Health(), SharedPreferencesAsync()),
);

final activityLogRepositoryProvider = Provider<ActivityLogRepository>(
  (ref) => ActivityLogRepositoryImpl(ref.watch(supabaseClientProvider)),
);

final setActivitySyncUseCaseProvider = Provider(
  (ref) => SetActivitySyncUseCase(
    ref.watch(fitnessRepositoryProvider),
    ref.watch(activityLogRepositoryProvider),
  ),
);

final getTodayActivityUseCaseProvider = Provider(
  (ref) => GetTodayActivityUseCase(
    ref.watch(fitnessRepositoryProvider),
    ref.watch(activityLogRepositoryProvider),
  ),
);

final calculateActivityAdjustedTargetUseCaseProvider = Provider(
  (ref) => CalculateActivityAdjustedTargetUseCase(
    ref.watch(calculateCalorieTargetUseCaseProvider),
  ),
);

final syncWeightFromHealthUseCaseProvider = Provider(
  (ref) => SyncWeightFromHealthUseCase(
    fitnessRepository: ref.watch(fitnessRepositoryProvider),
    profileRepository: ref.watch(profileRepositoryProvider),
    calculateTarget: ref.watch(calculateCalorieTargetUseCaseProvider),
  ),
);

/// Runs one weight sync; the value is the newly synced weight, or `null`
/// if nothing changed. `HomeScreen` watches it (so it runs on launch and
/// on pull-to-refresh via invalidation) and refreshes the profile when it
/// yields a weight.
final healthWeightSyncProvider = FutureProvider<double?>((ref) async {
  final userId = ref.watch(authRepositoryProvider).currentUserId;
  if (userId == null) return null;
  return ref.watch(syncWeightFromHealthUseCaseProvider)(userId);
});

final setMealWriteBackUseCaseProvider = Provider(
  (ref) => SetMealWriteBackUseCase(ref.watch(fitnessRepositoryProvider)),
);

final writeMealToHealthUseCaseProvider = Provider(
  (ref) => WriteMealToHealthUseCase(ref.watch(fitnessRepositoryProvider)),
);

final removeMealFromHealthUseCaseProvider = Provider(
  (ref) => RemoveMealFromHealthUseCase(ref.watch(fitnessRepositoryProvider)),
);

final mealWriteBackEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(fitnessRepositoryProvider).isMealWriteBackEnabled(),
);

final activitySyncEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(fitnessRepositoryProvider).isSyncEnabled(),
);

/// Today's activity for the account (from this device's health store if it
/// syncs, otherwise whatever another device uploaded), or `null`.
/// Refreshed by invalidating (pull-to-refresh on `HomeScreen`, toggling
/// sync in `SettingsScreen`) — no background sync.
final todayActivityProvider = FutureProvider<DailyActivity?>((ref) async {
  final userId = ref.watch(authRepositoryProvider).currentUserId;
  if (userId == null) return null;
  final profile = await ref.watch(currentUserProfileProvider.future);
  return ref.watch(getTodayActivityUseCaseProvider)(
    userId,
    weightKg: profile?.weightKg,
  );
});

/// Today's calorie budget, as `HomeScreen`, `PlanScreen` and Ask AI present
/// it: the plan's target, or — on the dynamic calorie mode with activity
/// synced today — the sedentary base plus active energy burned (see
/// `CalculateActivityAdjustedTargetUseCase`). Dynamic with nothing synced
/// yet falls back to the plan target. `null` until the profile loads.
final todayCalorieBudgetProvider = Provider<int?>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null) return null;
  final activity = ref.watch(todayActivityProvider).value;
  final adjusted = activity == null
      ? null
      : ref.watch(calculateActivityAdjustedTargetUseCaseProvider)(
          profile,
          activity,
        );
  return adjusted ?? profile.dailyCalorieTarget;
});
