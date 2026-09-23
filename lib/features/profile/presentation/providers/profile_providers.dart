import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/avatar_remote_data_source.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/avatar_repository_impl.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/calculate_calorie_target_usecase.dart';
import '../../domain/usecases/complete_onboarding_usecase.dart';
import '../../domain/usecases/fetch_user_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';

final _profileRemoteDataSourceProvider = Provider(
  (ref) => ProfileRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(_profileRemoteDataSourceProvider)),
);

final fetchUserProfileUseCaseProvider = Provider(
  (ref) => FetchUserProfileUseCase(ref.watch(profileRepositoryProvider)),
);

/// Shared by the onboarding wizard and the "edit my plan" screen — both
/// compute the same daily calorie target from the same answers.
final calculateCalorieTargetUseCaseProvider = Provider(
  (ref) => const CalculateCalorieTargetUseCase(),
);

final completeOnboardingUseCaseProvider = Provider(
  (ref) => CompleteOnboardingUseCase(ref.watch(profileRepositoryProvider)),
);

final updateProfileUseCaseProvider = Provider(
  (ref) => UpdateProfileUseCase(ref.watch(profileRepositoryProvider)),
);

final _avatarRemoteDataSourceProvider = Provider(
  (ref) => AvatarRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => AvatarRepositoryImpl(ref.watch(_avatarRemoteDataSourceProvider)),
);

final uploadAvatarUseCaseProvider = Provider(
  (ref) => UploadAvatarUseCase(
    avatarRepository: ref.watch(avatarRepositoryProvider),
    profileRepository: ref.watch(profileRepositoryProvider),
  ),
);

/// The signed-in user's profile, or `null` if not signed in / no row yet.
/// Watched by `_AuthGate` (main.dart) to decide whether to show
/// `OnboardingScreen` or `AppShell` — invalidated by `OnboardingScreen`
/// once it finishes, so the app reactively swaps over.
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return null;
  return ref.watch(fetchUserProfileUseCaseProvider)(userId);
});
