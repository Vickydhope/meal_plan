import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/ask_ai/domain/entities/ask_ai_stream_event.dart';
import 'package:meal_plan/features/ask_ai/domain/entities/chat_message.dart';
import 'package:meal_plan/features/ask_ai/domain/repositories/ask_ai_repository.dart';
import 'package:meal_plan/features/ask_ai/domain/usecases/ask_ai_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockAskAiRepository extends Mock implements AskAiRepository {}

void main() {
  late _MockAskAiRepository repository;
  late AskAiUseCase useCase;

  setUp(() {
    repository = _MockAskAiRepository();
    useCase = AskAiUseCase(repository);
  });

  test('delegates to the repository with the given question and history', () {
    const history = [ChatMessage(role: ChatRole.user, text: 'Hi')];
    final events = Stream<AskAiStreamEvent>.fromIterable(const [
      AskAiDelta('Hello'),
      AskAiCompleted(),
    ]);
    when(
      () => repository.ask(question: 'How many calories?', history: history),
    ).thenAnswer((_) => events);

    final result = useCase(question: 'How many calories?', history: history);

    expect(result, events);
    verify(
      () => repository.ask(question: 'How many calories?', history: history),
    ).called(1);
  });
}
