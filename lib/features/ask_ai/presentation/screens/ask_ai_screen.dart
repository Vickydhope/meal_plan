import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../app_shell/presentation/screens/app_shell.dart'
    show kAppBottomBarHeight;
import '../../domain/entities/chat_message.dart';
import '../providers/ask_ai_providers.dart';

/// Quick-start prompts shown before the user has sent anything, and as a
/// slim strip above the input once a conversation is underway.
const _quickSuggestions = [
  'How many calories should I eat today?',
  'Suggest a high-protein breakfast',
  "What's a healthy snack?",
  'Explain my macros',
];

/// Chat UI for the nutrition assistant, backed by the `ask-ai` Supabase
/// Edge Function (Gemini), personalized with the signed-in user's profile
/// and today's logged meals. See [AskAiNotifier] for the streaming
/// send/receive orchestration.
class AskAiScreen extends ConsumerStatefulWidget {
  const AskAiScreen({super.key});

  @override
  ConsumerState<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends ConsumerState<AskAiScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    _scrollToBottom();
    ref.read(askAiProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(askAiProvider, (previous, next) {
      if (next.messages.length != (previous?.messages.length ?? 0)) {
        _scrollToBottom();
      }
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final state = ref.watch(askAiProvider);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Cravia', style: AppTypography.titleLarge),
            Text('Your nutrition assistant', style: AppTypography.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _WelcomeState(onSuggestionTap: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return _ChatBubble(message: message);
                    },
                  ),
          ),
          if (state.messages.isNotEmpty)
            _QuickSuggestionsStrip(onSuggestionTap: _send),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + (keyboardOpen ? 0 : kAppBottomBarHeight * 1.25),
            ),
            child: _ChatInputBar(
              controller: _controller,
              enabled: !state.isStreaming,
              onSend: _send,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered greeting + the full set of starter prompts, shown before the
/// user has sent a first message.
class _WelcomeState extends StatelessWidget {
  const _WelcomeState({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.sparkles,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Hi! I'm Cravia, your nutrition assistant",
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Ask me about your meals, macros, or what to eat next.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final suggestion in _quickSuggestions)
                _SuggestionChip(
                  label: suggestion,
                  onTap: () => onSuggestionTap(suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Slim horizontally-scrolling row of the same starter prompts, kept
/// available above the input once the conversation is underway.
class _QuickSuggestionsStrip extends StatelessWidget {
  const _QuickSuggestionsStrip({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = _quickSuggestions[index];
          return _SuggestionChip(
            label: suggestion,
            onTap: () => onSuggestionTap(suggestion),
          );
        },
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: AppTypography.bodySmall),
      ),
    );
  }
}

/// A single chat row — user messages align right in a solid primary
/// bubble, assistant messages align left in an outlined surface bubble
/// with a small avatar. An assistant message with empty, still-streaming
/// text renders the "Typing…" placeholder in the same shape.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final showTypingPlaceholder = message.isStreaming && message.text.isEmpty;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppSpacing.radiusMd),
          topRight: const Radius.circular(AppSpacing.radiusMd),
          bottomLeft: Radius.circular(isUser ? AppSpacing.radiusMd : 4),
          bottomRight: Radius.circular(isUser ? 4 : AppSpacing.radiusMd),
        ),
        border: isUser ? null : Border.all(color: AppColors.border),
      ),
      child: showTypingPlaceholder
          ? Text(
              'Typing…',
              style: AppTypography.bodyMedium.copyWith(
                fontStyle: FontStyle.italic,
              ),
            )
          : Text(
              message.text,
              style: AppTypography.bodyLarge.copyWith(
                color: isUser ? AppColors.onScrim : AppColors.textPrimary,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              height: 28,
              width: 28,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.sparkles,
                color: AppColors.accent,
                size: 14,
              ),
            ),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Ask about your meals…',
                hintStyle: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: enabled ? onSend : null,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: enabled ? AppColors.primary : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                LucideIcons.arrow_up,
                color: AppColors.onScrim,
                size: 18,
              ),
              tooltip: 'Send',
              visualDensity: VisualDensity.compact,
              onPressed: enabled ? () => onSend(controller.text) : null,
            ),
          ),
        ],
      ),
    );
  }
}
