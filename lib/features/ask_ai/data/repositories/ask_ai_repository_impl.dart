import '../../../../core/error/app_exception.dart';
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
    int? calorieBudgetKcal,
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

      // "Today" must match the device's local calendar day, not the edge
      // function's own (UTC) clock — otherwise its meal-totals context
      // drifts from what the dashboard shows for users off UTC. Mirrors
      // MealLogRepositoryImpl.fetchLogsForDate's local-midnight boundary.
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      await for (final raw in _dataSource.streamAskAi(
        question: question,
        history: historyPayload,
        dayStartUtc: dayStart.toUtc().toIso8601String(),
        dayEndUtc: dayEnd.toUtc().toIso8601String(),
        // Keys the synced `daily_activity` row for "today" server-side.
        localDate: DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).toIso8601String().split('T').first,
        calorieBudgetKcal: calorieBudgetKcal,
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
      yield AskAiFailed(userMessageFor(err));
    }
  }
}
