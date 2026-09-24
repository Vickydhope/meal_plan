import '../entities/ask_ai_stream_event.dart';
import '../entities/chat_message.dart';

abstract class AskAiRepository {
  /// Sends [question] (with prior [history] for conversational context) to
  /// the nutrition assistant, streaming [AskAiDelta] chunks of the reply as
  /// they arrive, followed by a terminal [AskAiCompleted] or [AskAiFailed].
  Stream<AskAiStreamEvent> ask({
    required String question,
    required List<ChatMessage> history,
    int? calorieBudgetKcal,
  });
}
