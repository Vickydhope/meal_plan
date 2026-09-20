import '../../domain/entities/chat_message.dart';

class AskAiState {
  const AskAiState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
  });

  final List<ChatMessage> messages;

  /// True while the assistant's reply to the last message is still
  /// streaming in.
  final bool isStreaming;
  final String? error;

  AskAiState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? error,
    bool clearError = false,
  }) {
    return AskAiState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
