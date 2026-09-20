enum ChatRole { user, assistant }

/// One turn in an Ask AI conversation.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
  });

  final ChatRole role;
  final String text;

  /// True while an assistant message's text is still being appended to as
  /// Gemini's response streams in.
  final bool isStreaming;

  ChatMessage copyWith({String? text, bool? isStreaming}) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
