import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part6_source.dart';
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

Map<String, dynamic> _passage(int i) => {
      'passageText': 'Passage $i (1)___ (2)___ (3)___ (4)___ text.',
      'questions': List.generate(
        4,
        (q) => {
          'options': ['a', 'b', 'c', 'd'],
          'correctIndex': q % 4,
          'explanation': 'Explanation $i-$q',
        },
      ),
    };

void main() {
  test('parses 3 passages of 4 questions each from a valid AI response', () async {
    final json = jsonEncode({'passages': List.generate(3, _passage)});
    final source = Part6Source.withModel(FakeGenerativeModelClient(json));

    final set = await source.generate(
      context: AppContext.business,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol4},
    );

    expect(set.passages.length, 3);
    expect(set.passages[0].questions.length, 4);
    expect(set.passages[0].passageText, contains('(1)___'));
    expect(set.passages[0].questions[0].explanation, 'Explanation 0-0');
    expect(set.volumes, {EconomyVolume.vol4});
    expect(set.context, AppContext.business);
    expect(set.targetLanguage, Language.english);
    expect(set.id, isNotEmpty);
  });

  test('throws when the AI response has no passages', () async {
    final source = Part6Source.withModel(
      FakeGenerativeModelClient('{"passages":[]}'),
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
    final client = FakeGenerativeModelClient(
      jsonEncode({'passages': List.generate(3, _passage)}),
    );
    final source = Part6Source.withModel(client);

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

  test('prompt requires at least one sentence-insertion blank per passage', () async {
    final client = FakeGenerativeModelClient(
      jsonEncode({'passages': List.generate(3, _passage)}),
    );
    final source = Part6Source.withModel(client);

    await source.generate(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );

    final part = client.lastPrompt!.first.parts.first as TextPart;
    expect(part.text.toLowerCase(), contains('select the sentence that best fits'));
  });
}
