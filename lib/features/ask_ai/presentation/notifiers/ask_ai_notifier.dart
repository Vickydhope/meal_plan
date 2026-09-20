import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ask_ai_stream_event.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/ask_ai_providers.dart';
import '../state/ask_ai_state.dart';

/// Presentation-layer orchestrator for the Ask AI chat. Pulls its use case
/// from providers rather than talking to Supabase directly.
class AskAiNotifier extends Notifier<AskAiState> {
  StreamSubscription<AskAiStreamEvent>? _replySub;

  @override
  AskAiState build() {
    ref.onDispose(() => _replySub?.cancel());
    return const AskAiState();
  }

  /// Sends [question], appending it plus a placeholder streaming assistant
  /// reply to the conversation, then streams the assistant's answer in.
  Future<void> send(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || state.isStreaming) return;

    final historyBeforeSend = state.messages;
    state = state.copyWith(
      messages: [
        ...historyBeforeSend,
        ChatMessage(role: ChatRole.user, text: trimmed),
        const ChatMessage(role: ChatRole.assistant, text: '', isStreaming: true),
      ],
      isStreaming: true,
      clearError: true,
    );

    await _replySub?.cancel();
    final buffer = StringBuffer();
    final completer = Completer<void>();

    _replySub = ref
        .read(askAiUseCaseProvider)(question: trimmed, history: historyBeforeSend)
        .listen(
          (event) => switch (event) {
            AskAiDelta(:final text) => _appendDelta(buffer, text),
            AskAiCompleted() => _finishAssistantMessage(buffer.toString()),
            AskAiFailed(:final message) =>
              _finishAssistantMessage(buffer.toString(), error: message),
          },
          onError: (Object err) =>
              _finishAssistantMessage(buffer.toString(), error: '$err'),
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

    await completer.future;
  }

  void _appendDelta(StringBuffer buffer, String text) {
    buffer.write(text);
    _replaceLastMessage(
      ChatMessage(role: ChatRole.assistant, text: buffer.toString(), isStreaming: true),
    );
  }

  void _finishAssistantMessage(String text, {String? error}) {
    final fallback = text.isEmpty && error != null
        ? "Sorry, I couldn't get an answer for that — please try again."
        : text;
    _replaceLastMessage(
      ChatMessage(role: ChatRole.assistant, text: fallback, isStreaming: false),
    );
    state = state.copyWith(isStreaming: false, error: error);
  }

  void _replaceLastMessage(ChatMessage message) {
    if (state.messages.isEmpty) return;
    final messages = [...state.messages];
    messages[messages.length - 1] = message;
    state = state.copyWith(messages: messages);
  }
}
