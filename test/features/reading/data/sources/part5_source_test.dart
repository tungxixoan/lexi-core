import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part5_source.dart';
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
      'sentenceWithBlank': 'Sentence $i ___.',
      'options': ['a', 'b', 'c', 'd'],
      'correctIndex': i % 4,
      'explanation': 'Explanation $i',
    };

void main() {
  test('parses 15 questions from a valid AI response', () async {
    final json = jsonEncode({
      'questions': List.generate(15, _question),
    });
    final source = Part5Source.withModel(FakeGenerativeModelClient(json));

    final set = await source.generate(
      context: AppContext.business,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );

    expect(set.questions.length, 15);
    expect(set.questions[0].sentenceWithBlank, 'Sentence 0 ___.');
    expect(set.questions[0].options.length, 4);
    expect(set.questions[0].explanation, 'Explanation 0');
    expect(set.volumes, {EconomyVolume.vol3});
    expect(set.context, AppContext.business);
    expect(set.targetLanguage, Language.english);
    expect(set.id, isNotEmpty);
  });

  test('throws when the AI response has no questions', () async {
    final source = Part5Source.withModel(
      FakeGenerativeModelClient('{"questions":[]}'),
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
      jsonEncode({'questions': List.generate(15, _question)}),
    );
    final source = Part5Source.withModel(client);

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

  test('non-empty volumes selection sends only the selected volume labels', () async {
    final client = FakeGenerativeModelClient(
      jsonEncode({'questions': List.generate(15, _question)}),
    );
    final source = Part5Source.withModel(client);

    await source.generate(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol4},
    );

    final part = client.lastPrompt!.first.parts.first as TextPart;
    expect(part.text, contains('Vol 4'));
    expect(part.text, isNot(contains('Vol 2')));
    expect(part.text, isNot(contains('Vol 3')));
    expect(part.text, isNot(contains('Vol 5')));
  });
}
