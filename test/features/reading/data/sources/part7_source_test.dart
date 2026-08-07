import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part7_source.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';

class FakeGenerativeModelClient implements GenerativeModelClient {
  FakeGenerativeModelClient(this._responseText);
  final String _responseText;
  Iterable<Content>? lastPrompt;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    lastPrompt = prompt;
    return GenerateContentResponse(
      [Candidate(Content.text(_responseText), null, null, null, null)],
      null,
    );
  }
}

Map<String, dynamic> _question(int i) => {
      'question': 'Question $i?',
      'options': ['a', 'b', 'c', 'd'],
      'correctIndex': i % 4,
      'explanation': 'Explanation $i',
    };

Map<String, dynamic> _singleGroup(int i, int questionCount) => {
      'documents': ['Document $i'],
      'questions': List.generate(questionCount, _question),
    };

Map<String, dynamic> _doubleGroup() => {
      'documents': ['Document A', 'Document B'],
      'questions': List.generate(5, _question),
    };

Map<String, dynamic> _wellFormedResponse() => {
      'passageGroups': [_singleGroup(0, 3), _singleGroup(1, 4), _doubleGroup()],
    };

void main() {
  test('parses a well-formed 3-group response into a Part7Set', () async {
    final json = jsonEncode(_wellFormedResponse());
    final source = Part7Source.withModel(FakeGenerativeModelClient(json));

    final set = await source.generate(
      context: AppContext.business,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );

    expect(set.passageGroups.length, 3);
    expect(set.passageGroups[0].documents.length, 1);
    expect(set.passageGroups[0].questions.length, 3);
    expect(set.passageGroups[1].documents.length, 1);
    expect(set.passageGroups[1].questions.length, 4);
    expect(set.passageGroups[2].documents.length, 2);
    expect(set.passageGroups[2].questions.length, 5);
    expect(set.passageGroups[0].questions[0].explanation, 'Explanation 0');
    expect(set.volumes, {EconomyVolume.vol3});
    expect(set.context, AppContext.business);
    expect(set.targetLanguage, Language.english);
    expect(set.id, isNotEmpty);
  });

  test('throws when the AI response has no passage groups', () async {
    final source = Part7Source.withModel(
      FakeGenerativeModelClient('{"passageGroups":[]}'),
    );

    expect(
      () => source.generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol3},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('throws when a single-passage group has the wrong document count', () async {
    final malformed = {
      'passageGroups': [
        _doubleGroup(), // wrong: group 0 must be single-passage (1 document), not 2
        _singleGroup(1, 4),
        _doubleGroup(),
      ],
    };
    final source = Part7Source.withModel(
      FakeGenerativeModelClient(jsonEncode(malformed)),
    );

    expect(
      () => source.generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol3},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('throws when the double-passage group has the wrong question count', () async {
    final malformed = {
      'passageGroups': [
        _singleGroup(0, 3),
        _singleGroup(1, 4),
        _singleGroup(2, 4), // wrong: group 2 must be double-passage (2 docs, 5 questions)
      ],
    };
    final source = Part7Source.withModel(
      FakeGenerativeModelClient(jsonEncode(malformed)),
    );

    expect(
      () => source.generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol3},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('throws when a single-passage group has an out-of-range question count', () async {
    final malformed = {
      'passageGroups': [
        _singleGroup(0, 2), // wrong: single-passage groups must have 3 or 4 questions, not 2
        _singleGroup(1, 4),
        _doubleGroup(),
      ],
    };
    final source = Part7Source.withModel(
      FakeGenerativeModelClient(jsonEncode(malformed)),
    );

    expect(
      () => source.generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol3},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('empty volumes selection sends all 4 volume labels in the prompt', () async {
    final client = FakeGenerativeModelClient(jsonEncode(_wellFormedResponse()));
    final source = Part7Source.withModel(client);

    await source.generate(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {},
    );

    final part = client.lastPrompt!.first.parts.first as TextPart;
    expect(part.text, contains('Vol 2'));
    expect(part.text, contains('Vol 3'));
    expect(part.text, contains('Vol 4'));
    expect(part.text, contains('Vol 5'));
  });

  test('prompt requires the double-passage group to need both documents', () async {
    final client = FakeGenerativeModelClient(jsonEncode(_wellFormedResponse()));
    final source = Part7Source.withModel(client);

    await source.generate(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );

    final part = client.lastPrompt!.first.parts.first as TextPart;
    expect(part.text.toLowerCase(), contains('both'));
  });

  test('prompt includes the Vietnamese-script guard for the explanation field', () async {
    final client = FakeGenerativeModelClient(jsonEncode(_wellFormedResponse()));
    final source = Part7Source.withModel(client);

    await source.generate(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );

    final part = client.lastPrompt!.first.parts.first as TextPart;
    expect(part.text, contains('Vietnamese script'));
  });
}
