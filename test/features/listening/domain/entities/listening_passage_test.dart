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

    test('gender is null when not provided', () {
      const turn = ListeningTurn(speaker: 'A', text: 'Hello there.');
      expect(turn.gender, isNull);
    });

    test('holds a declared gender', () {
      const turn =
          ListeningTurn(speaker: 'A', gender: 'female', text: 'Hello there.');
      expect(turn.gender, 'female');
    });

    test('toJson / fromJson round-trips (speaker + text match web)', () {
      const turn =
          ListeningTurn(speaker: 'A', gender: 'female', text: 'Hello there.');
      final json = turn.toJson();
      expect(
          json, {'speaker': 'A', 'gender': 'female', 'text': 'Hello there.'});
      final decoded = ListeningTurn.fromJson(json);
      expect(decoded.speaker, 'A');
      expect(decoded.gender, 'female');
      expect(decoded.text, 'Hello there.');
    });

    test('fromJson tolerates a web turn with no gender key', () {
      final decoded =
          ListeningTurn.fromJson({'speaker': null, 'text': 'Attention.'});
      expect(decoded.speaker, isNull);
      expect(decoded.gender, isNull);
      expect(decoded.text, 'Attention.');
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
          options: [
            'A restaurant',
            'A clothing store',
            'An airport',
            'A hospital'
          ],
          correctIndex: 1,
        ),
        ListeningQuestion(
          question: 'What does the customer want?',
          options: ['A refund', 'Directions', 'A jacket', 'A discount'],
          correctIndex: 2,
        ),
        ListeningQuestion(
          question: 'What is implied about the customer?',
          options: [
            'They are in a hurry',
            'They are shopping',
            'They are lost',
            'They are complaining'
          ],
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

    test('speakerGenders defaults to empty when not provided', () {
      expect(passage.speakerGenders, isEmpty);
    });

    test('toJson / fromJson round-trips including speakerGenders', () {
      final original = ListeningPassage(
        id: 'p1',
        kind: ListeningKind.conversation,
        turns: const [
          ListeningTurn(speaker: 'A', gender: 'male', text: 'Hi.'),
          ListeningTurn(speaker: 'B', gender: 'female', text: 'Hello.'),
        ],
        questions: const [
          ListeningQuestion(
            question: 'Where?',
            options: ['a', 'b', 'c', 'd'],
            correctIndex: 1,
          ),
        ],
        speakerGenders: const {'A': 'male', 'B': 'female'},
        level: CEFRLevel.b2,
        context: AppContext.travel,
        targetLanguage: Language.english,
        generatedAt: DateTime(2026, 7, 19),
      );
      final json = original.toJson();
      expect(json['kind'], 'conversation');
      expect(json['speakerGenders'], {'A': 'male', 'B': 'female'});
      expect(json['level'], 'b2');
      expect(json['context'], 'travel');

      final restored = ListeningPassage.fromJson(json);
      expect(restored.id, 'p1');
      expect(restored.kind, ListeningKind.conversation);
      expect(restored.turns.length, 2);
      expect(restored.turns[0].text, 'Hi.');
      expect(restored.questions.single.correctIndex, 1);
      expect(restored.speakerGenders, {'A': 'male', 'B': 'female'});
      expect(restored.level, CEFRLevel.b2);
      expect(restored.context, AppContext.travel);
      expect(restored.targetLanguage, Language.english);
      expect(restored.generatedAt, DateTime(2026, 7, 19));

      // speakerGenders survives the round-trip, so assignVoices still gives
      // two distinct-gender voices rather than collapsing to female/female.
      expect(assignVoices(restored)['A'], 'male1');
      expect(assignVoices(restored)['B'], 'female1');
    });
  });

  group('speakerKey', () {
    test('returns the speaker letter unchanged', () {
      expect(speakerKey('A'), 'A');
      expect(speakerKey('B'), 'B');
    });
    test('returns "solo" for a null speaker (talk format)', () {
      expect(speakerKey(null), 'solo');
    });
  });

  group('assignVoices', () {
    ListeningPassage passageWith(
            List<ListeningTurn> turns, Map<String, String> genders) =>
        ListeningPassage(
          id: 'p',
          kind: ListeningKind.conversation,
          turns: turns,
          questions: const [],
          speakerGenders: genders,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        );

    test('assigns distinct voices to two speakers of different genders', () {
      final passage = passageWith(
        const [
          ListeningTurn(speaker: 'A', text: 'Hi.'),
          ListeningTurn(speaker: 'B', text: 'Hello.'),
        ],
        {'A': 'male', 'B': 'female'},
      );
      final voices = assignVoices(passage);
      expect(voices['A'], 'male1');
      expect(voices['B'], 'female1');
    });

    test('two speakers of the same gender get slot 1 and slot 2', () {
      final passage = passageWith(
        const [
          ListeningTurn(speaker: 'A', text: 'Hi.'),
          ListeningTurn(speaker: 'B', text: 'Hello.'),
        ],
        {'A': 'male', 'B': 'male'},
      );
      final voices = assignVoices(passage);
      expect(voices['A'], 'male1');
      expect(voices['B'], 'male2');
    });

    test('orders by first appearance, not alphabetically', () {
      final passage = passageWith(
        const [
          ListeningTurn(speaker: 'B', text: 'Hi.'),
          ListeningTurn(speaker: 'A', text: 'Hello.'),
        ],
        {'A': 'male', 'B': 'female'},
      );
      final voices = assignVoices(passage);
      expect(voices['B'], 'female1');
      expect(voices['A'], 'male1');
    });

    test('defaults a speaker with no declared gender to female', () {
      final passage = passageWith(
        const [ListeningTurn(speaker: 'A', text: 'Hi.')],
        const {},
      );
      expect(assignVoices(passage)['A'], 'female1');
    });

    test('a single-speaker talk gets one voice keyed by "solo"', () {
      final passage = passageWith(
        const [
          ListeningTurn(text: 'Attention all passengers.'),
          ListeningTurn(text: 'Flight 204 is now boarding.'),
        ],
        {'solo': 'male'},
      );
      final voices = assignVoices(passage);
      expect(voices['solo'], 'male1');
      expect(voices.length, 1);
    });
  });
}
