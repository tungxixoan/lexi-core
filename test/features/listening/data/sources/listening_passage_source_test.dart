import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/data/sources/listening_passage_source.dart';

class FakeGenerativeModelClient implements GenerativeModelClient {
  FakeGenerativeModelClient(this._responseText);
  final String _responseText;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    return GenerateContentResponse(
      [Candidate(Content.text(_responseText), null, null, null, null)],
      null,
    );
  }
}

void main() {
  final conversationJson = jsonEncode({
    'kind': 'conversation',
    'turns': [
      {'speaker': 'A', 'text': 'Can I help you find something?'},
      {'speaker': 'B', 'text': 'Yes, I am looking for a winter jacket.'},
    ],
    'questions': [
      {
        'question': 'Where does this conversation take place?',
        'options': ['A restaurant', 'A clothing store', 'An airport', 'A hospital'],
        'correctIndex': 1,
      },
      {
        'question': 'What is the customer looking for?',
        'options': ['A refund', 'Directions', 'A jacket', 'A discount'],
        'correctIndex': 2,
      },
      {
        'question': 'What time of year is implied?',
        'options': ['Summer', 'Winter', 'Spring', 'Fall'],
        'correctIndex': 1,
      },
    ],
  });

  test('parses a conversation response into a ListeningPassage', () async {
    final source = ListeningPassageSource.withModel(
      FakeGenerativeModelClient(conversationJson),
    );
    final passage = await source.generate(
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );

    expect(passage.kind, ListeningKind.conversation);
    expect(passage.turns.length, 2);
    expect(passage.turns[0].speaker, 'A');
    expect(passage.turns[1].speaker, 'B');
    expect(passage.questions.length, 3);
    expect(passage.questions[0].options.length, 4);
    expect(passage.questions[0].correctIndex, 1);
    expect(passage.level, CEFRLevel.b1);
    expect(passage.targetLanguage, Language.english);
    expect(passage.id, isNotEmpty);
  });

  test('parses a talk response (null speaker) into a ListeningPassage', () async {
    final talkJson = jsonEncode({
      'kind': 'talk',
      'turns': [
        {'speaker': null, 'text': 'Attention all passengers.'},
        {'speaker': null, 'text': 'Flight 204 is now boarding at gate 12.'},
      ],
      'questions': [
        {
          'question': 'What is being announced?',
          'options': ['A delay', 'A boarding call', 'A cancellation', 'A gate change'],
          'correctIndex': 1,
        },
        {
          'question': 'What is the flight number?',
          'options': ['104', '204', '402', '240'],
          'correctIndex': 1,
        },
        {
          'question': 'Where should passengers go?',
          'options': ['Gate 12', 'Gate 21', 'Baggage claim', 'Security'],
          'correctIndex': 0,
        },
      ],
    });
    final source = ListeningPassageSource.withModel(
      FakeGenerativeModelClient(talkJson),
    );
    final passage = await source.generate(
      level: CEFRLevel.a2,
      context: AppContext.travel,
      targetLanguage: Language.english,
    );

    expect(passage.kind, ListeningKind.talk);
    expect(passage.turns.every((t) => t.speaker == null), isTrue);
    expect(passage.questions.length, 3);
  });
}
