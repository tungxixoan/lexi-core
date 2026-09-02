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

  String? capturedPrompt;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    capturedPrompt = prompt
        .expand((c) => c.parts)
        .whereType<TextPart>()
        .map((p) => p.text)
        .join();
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
      {'speaker': 'A', 'gender': 'female', 'text': 'Can I help you find something?'},
      {'speaker': 'B', 'gender': 'male', 'text': 'Yes, I am looking for a winter jacket.'},
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
    expect(passage.turns[0].gender, 'female');
    expect(passage.turns[1].gender, 'male');
    expect(passage.speakerGenders, {'A': 'female', 'B': 'male'});
    expect(passage.questions.length, 3);
    expect(passage.questions[0].options.length, 4);
    expect(passage.questions[0].correctIndex, 1);
    expect(passage.level, CEFRLevel.b1);
    expect(passage.targetLanguage, Language.english);
    expect(passage.id, isNotEmpty);
  });

  test(
      'prompt keeps A/B as internal speaker labels but forbids them in the dialogue and questions',
      () async {
    final fake = FakeGenerativeModelClient(conversationJson);
    final source = ListeningPassageSource.withModel(fake);
    await source.generate(
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    final prompt = fake.capturedPrompt!;

    // still asks for the structural label in the JSON shape
    expect(prompt, contains('"speaker": "A" or "B" or null'));
    // dialogue rule: the bare letters must not appear in any turn text
    expect(prompt, contains('The letters "A" and "B" must NEVER'));
    expect(prompt, contains('never as "A" or "B"'));
    // question-reference rules: gender, then role, then first name
    expect(prompt, contains('người đàn ông'));
    expect(prompt, contains('người phụ nữ'));
    expect(
      prompt,
      anyOf(contains('khách hàng'), contains('role in the situation')),
    );
    expect(prompt, contains('người nói'));
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

  test('throws when the AI response falls back to empty turns/questions',
      () async {
    final source = ListeningPassageSource.withModel(
      FakeGenerativeModelClient(
        '{"kind":"talk","turns":[],"questions":[]}',
      ),
    );

    expect(
      () => source.generate(
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('speakerGenders uses the first-seen gender when a later turn disagrees', () async {
    final inconsistentJson = jsonEncode({
      'kind': 'conversation',
      'turns': [
        {'speaker': 'A', 'gender': 'female', 'text': 'Can I help you?'},
        {'speaker': 'B', 'gender': 'male', 'text': 'Yes, please.'},
        {'speaker': 'A', 'gender': 'male', 'text': 'Sure thing.'}, // inconsistent — ignored
      ],
      'questions': [
        {'question': 'Q1', 'options': ['a', 'b', 'c', 'd'], 'correctIndex': 0},
        {'question': 'Q2', 'options': ['a', 'b', 'c', 'd'], 'correctIndex': 0},
        {'question': 'Q3', 'options': ['a', 'b', 'c', 'd'], 'correctIndex': 0},
      ],
    });
    final source = ListeningPassageSource.withModel(
      FakeGenerativeModelClient(inconsistentJson),
    );
    final passage = await source.generate(
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );

    expect(passage.speakerGenders['A'], 'female'); // first-seen wins, not the 3rd turn's 'male'
  });
}
