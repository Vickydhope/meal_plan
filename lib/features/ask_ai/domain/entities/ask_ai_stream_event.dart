/// One event in a streamed Ask AI reply — see [AskAiRepository.ask].
sealed class AskAiStreamEvent {
  const AskAiStreamEvent();
}

/// A chunk of the assistant's reply text, to be appended to what's been
/// received so far.
class AskAiDelta extends AskAiStreamEvent {
  const AskAiDelta(this.text);
  final String text;
}

/// The reply finished streaming successfully.
class AskAiCompleted extends AskAiStreamEvent {
  const AskAiCompleted();
}

class AskAiFailed extends AskAiStreamEvent {
  const AskAiFailed(this.message);
  final String message;
}
