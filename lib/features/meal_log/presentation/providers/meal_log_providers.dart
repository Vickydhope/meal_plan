import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/food_analysis_remote_data_source.dart';
import '../../data/datasources/image_remote_data_source.dart';
import '../../data/datasources/meal_log_remote_data_source.dart';
import '../../data/repositories/food_analysis_repository_impl.dart';
import '../../data/repositories/image_repository_impl.dart';
import '../../data/repositories/meal_log_repository_impl.dart';
import '../../domain/repositories/food_analysis_repository.dart';
import '../../domain/repositories/image_repository.dart';
import '../../domain/repositories/meal_log_repository.dart';
import '../../domain/usecases/analyze_meal_photo_usecase.dart';
import '../../domain/usecases/confirm_meal_log_usecase.dart';
import '../../domain/usecases/delete_meal_log_usecase.dart';
import '../../domain/usecases/discard_pending_meal_usecase.dart';
import '../../domain/usecases/fetch_meal_logs_usecase.dart';
import '../../domain/usecases/get_signed_image_url_usecase.dart';
import '../../domain/usecases/update_meal_log_usecase.dart';
import '../notifiers/meal_log_notifier.dart';
import '../state/meal_log_state.dart';

// --- Data sources ---

final _mealLogRemoteDataSourceProvider = Provider(
  (ref) => MealLogRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final _imageRemoteDataSourceProvider = Provider(
  (ref) => ImageRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final _foodAnalysisRemoteDataSourceProvider = Provider(
  (ref) => FoodAnalysisRemoteDataSource(ref.watch(supabaseClientProvider)),
);

// --- Repositories (bound to their domain interface) ---

final mealLogRepositoryProvider = Provider<MealLogRepository>(
  (ref) => MealLogRepositoryImpl(ref.watch(_mealLogRemoteDataSourceProvider)),
);

final imageRepositoryProvider = Provider<ImageRepository>(
  (ref) => ImageRepositoryImpl(ref.watch(_imageRemoteDataSourceProvider)),
);

final foodAnalysisRepositoryProvider = Provider<FoodAnalysisRepository>(
  (ref) => FoodAnalysisRepositoryImpl(
    ref.watch(_foodAnalysisRemoteDataSourceProvider),
  ),
);

// --- Use cases ---

final analyzeMealPhotoUseCaseProvider = Provider(
  (ref) => AnalyzeMealPhotoUseCase(
    imageRepository: ref.watch(imageRepositoryProvider),
    foodAnalysisRepository: ref.watch(foodAnalysisRepositoryProvider),
  ),
);

final fetchMealLogsUseCaseProvider = Provider(
  (ref) => FetchMealLogsUseCase(ref.watch(mealLogRepositoryProvider)),
);

final confirmMealLogUseCaseProvider = Provider(
  (ref) => ConfirmMealLogUseCase(ref.watch(mealLogRepositoryProvider)),
);

final deleteMealLogUseCaseProvider = Provider(
  (ref) => DeleteMealLogUseCase(ref.watch(mealLogRepositoryProvider)),
);

final updateMealLogUseCaseProvider = Provider(
  (ref) => UpdateMealLogUseCase(ref.watch(mealLogRepositoryProvider)),
);

final discardPendingMealUseCaseProvider = Provider(
  (ref) => DiscardPendingMealUseCase(ref.watch(imageRepositoryProvider)),
);

final getSignedImageUrlUseCaseProvider = Provider(
  (ref) => GetSignedImageUrlUseCase(ref.watch(imageRepositoryProvider)),
);

// --- Presentation state ---

final mealLogProvider = NotifierProvider<MealLogNotifier, MealLogState>(
  MealLogNotifier.new,
);
