import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/ask_ai_remote_data_source.dart';
import '../../data/repositories/ask_ai_repository_impl.dart';
import '../../domain/repositories/ask_ai_repository.dart';
import '../../domain/usecases/ask_ai_usecase.dart';
import '../notifiers/ask_ai_notifier.dart';
import '../state/ask_ai_state.dart';

final _askAiRemoteDataSourceProvider = Provider(
  (ref) => AskAiRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final askAiRepositoryProvider = Provider<AskAiRepository>(
  (ref) => AskAiRepositoryImpl(ref.watch(_askAiRemoteDataSourceProvider)),
);

final askAiUseCaseProvider = Provider(
  (ref) => AskAiUseCase(ref.watch(askAiRepositoryProvider)),
);

final askAiProvider = NotifierProvider<AskAiNotifier, AskAiState>(
  AskAiNotifier.new,
);
