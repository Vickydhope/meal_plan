import '../entities/ask_ai_stream_event.dart';
import '../entities/chat_message.dart';
import '../repositories/ask_ai_repository.dart';

class AskAiUseCase {
  AskAiUseCase(this._repository);

  final AskAiRepository _repository;

  Stream<AskAiStreamEvent> call({
    required String question,
    required List<ChatMessage> history,
  }) {
    return _repository.ask(question: question, history: history);
  }
}
