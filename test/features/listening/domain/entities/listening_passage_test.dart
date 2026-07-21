import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';

void main() {
  group('ListeningTurn', () {
    test('holds speaker and text', () {
      const turn = ListeningTurn(speaker: 'A', text: 'Hello there.');
      expect(turn.speaker, 'A');
      expect(turn.text, 'Hello there.');
    });

    test('speaker can be null for a talk', () {
      const turn = ListeningTurn(text: 'Attention all passengers.');
      expect(turn.speaker, isNull);
    });
  });

  group('ListeningQuestion', () {
    test('holds question, 4 options, and correct index', () {
      const question = ListeningQuestion(
        question: 'What is the main topic?',
        options: ['Weather', 'Travel', 'Food', 'Sports'],
        correctIndex: 1,
      );
      expect(question.options.length, 4);
      expect(question.correctIndex, 1);
    });
  });

  group('ListeningPassage', () {
    final passage = ListeningPassage(
      id: 'test-id',
      kind: ListeningKind.conversation,
      turns: const [
        ListeningTurn(speaker: 'A', text: 'Can I help you?'),
        ListeningTurn(speaker: 'B', text: 'Yes, I am looking for a jacket.'),
      ],
      questions: const [
        ListeningQuestion(
          question: 'Where does this conversation take place?',
          options: ['A restaurant', 'A clothing store', 'An airport', 'A hospital'],
          correctIndex: 1,
        ),
        ListeningQuestion(
          question: 'What does the customer want?',
          options: ['A refund', 'Directions', 'A jacket', 'A discount'],
          correctIndex: 2,
        ),
        ListeningQuestion(
          question: 'What is implied about the customer?',
          options: ['They are in a hurry', 'They are shopping', 'They are lost', 'They are complaining'],
          correctIndex: 1,
        ),
      ],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 7, 19),
    );

    test('has correct turn count', () {
      expect(passage.turns.length, 2);
    });

    test('always has exactly 3 questions', () {
      expect(passage.questions.length, 3);
    });

    test('holds kind, level, context, targetLanguage', () {
      expect(passage.kind, ListeningKind.conversation);
      expect(passage.level, CEFRLevel.b1);
      expect(passage.context, AppContext.general);
      expect(passage.targetLanguage, Language.english);
    });
  });
}
