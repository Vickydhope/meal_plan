import '../../domain/entities/ask_ai_stream_event.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ask_ai_repository.dart';
import '../datasources/ask_ai_remote_data_source.dart';

class AskAiRepositoryImpl implements AskAiRepository {
  AskAiRepositoryImpl(this._dataSource);

  final AskAiRemoteDataSource _dataSource;

  @override
  Stream<AskAiStreamEvent> ask({
    required String question,
    required List<ChatMessage> history,
  }) async* {
    try {
      final historyPayload = history
          .map(
            (message) => {
              'role': message.role == ChatRole.assistant
                  ? 'assistant'
                  : 'user',
              'text': message.text,
            },
          )
          .toList();

      await for (final raw in _dataSource.streamAskAi(
        question: question,
        history: historyPayload,
      )) {
        switch (raw['_event']) {
          case 'delta':
            yield AskAiDelta(raw['text'] as String? ?? '');
          case 'done':
            yield const AskAiCompleted();
          case 'error':
            yield AskAiFailed(raw['message'] as String? ?? 'Request failed');
        }
      }
    } catch (err) {
      yield AskAiFailed('Failed to reach the assistant: $err');
    }
  }
}
