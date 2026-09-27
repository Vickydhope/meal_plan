import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/ask_ai/data/datasources/ask_ai_remote_data_source.dart';
import 'package:meal_plan/features/ask_ai/data/repositories/ask_ai_repository_impl.dart';
import 'package:meal_plan/features/ask_ai/domain/entities/ask_ai_stream_event.dart';
import 'package:meal_plan/features/ask_ai/domain/entities/chat_message.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements AskAiRemoteDataSource {}

void main() {
  late _MockDataSource dataSource;
  late AskAiRepositoryImpl repository;

  setUp(() {
    dataSource = _MockDataSource();
    repository = AskAiRepositoryImpl(dataSource);
  });

  void stubStream(Stream<Map<String, dynamic>> stream) => when(
    () => dataSource.streamAskAi(
      question: any(named: 'question'),
      history: any(named: 'history'),
      dayStartUtc: any(named: 'dayStartUtc'),
      dayEndUtc: any(named: 'dayEndUtc'),
      localDate: any(named: 'localDate'),
      calorieBudgetKcal: any(named: 'calorieBudgetKcal'),
    ),
  ).thenAnswer((_) => stream);

  test(
    'maps SSE payloads to stream events and sends history + local day',
    () async {
      stubStream(
        Stream.fromIterable([
          {'_event': 'delta', 'text': 'Hi'},
          {'_event': 'unknown'},
          {'_event': 'error', 'message': 'Quota hit'},
          {'_event': 'done'},
        ]),
      );

      final events = await repository
          .ask(
            question: 'How am I doing?',
            history: const [
              ChatMessage(role: ChatRole.user, text: 'q1'),
              ChatMessage(role: ChatRole.assistant, text: 'a1'),
            ],
            calorieBudgetKcal: 2100,
          )
          .toList();

      expect(events[0], isA<AskAiDelta>().having((e) => e.text, 'text', 'Hi'));
      expect(
        events[1],
        isA<AskAiFailed>().having((e) => e.message, 'message', 'Quota hit'),
      );
      expect(events[2], isA<AskAiCompleted>());
      expect(events, hasLength(3));

      final now = DateTime.now();
      final captured = verify(
        () => dataSource.streamAskAi(
          question: 'How am I doing?',
          history: captureAny(named: 'history'),
          dayStartUtc: DateTime(
            now.year,
            now.month,
            now.day,
          ).toUtc().toIso8601String(),
          dayEndUtc: captureAny(named: 'dayEndUtc'),
          localDate: captureAny(named: 'localDate'),
          calorieBudgetKcal: 2100,
        ),
      ).captured;
      expect(captured[0], [
        {'role': 'user', 'text': 'q1'},
        {'role': 'assistant', 'text': 'a1'},
      ]);
      expect(captured[2], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    },
  );

  test('a thrown error ends the stream with a safe message', () async {
    stubStream(Stream.error(const AskAiException('Too many questions')));

    final events = await repository
        .ask(question: 'q', history: const [])
        .toList();

    expect(
      events.single,
      isA<AskAiFailed>().having(
        (e) => e.message,
        'message',
        'Too many questions',
      ),
    );
  });
}
