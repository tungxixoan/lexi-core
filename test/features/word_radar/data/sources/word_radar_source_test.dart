import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/word_radar/data/sources/word_radar_source.dart';

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

void main() {
  test('parses suggestions from the AI JSON response', () async {
    final json = jsonEncode({
      'suggestions': [
        {
          'headword': 'ubiquitous',
          'ipa': '/juːˈbɪkwɪtəs/',
          'meaning': 'có mặt khắp nơi',
          'definition': 'present, appearing, or found everywhere',
          'synonyms': ['omnipresent', 'pervasive'],
          'examples': ['Smartphones are ubiquitous nowadays.'],
          'suggestedTopics': ['Technology'],
          'cefrLevel': 'c1',
        },
      ],
    });
    final source = WordRadarSource.withModel(FakeGenerativeModelClient(json));

    final result = await source.scan(
      text: 'Smartphones are everywhere now.',
      targetLanguage: Language.english,
      targetCefrLevel: CEFRLevel.c1,
      knownHeadwords: const [],
    );

    expect(result, hasLength(1));
    expect(result[0].headword, 'ubiquitous');
    expect(result[0].ipa, '/juːˈbɪkwɪtəs/');
    expect(result[0].meaning, 'có mặt khắp nơi');
    expect(result[0].definition, 'present, appearing, or found everywhere');
    expect(result[0].synonyms, ['omnipresent', 'pervasive']);
    expect(result[0].suggestedTopics, ['Technology']);
    expect(result[0].cefrLevel, CEFRLevel.c1);
  });

  test('returns an empty list when the AI has nothing to suggest', () async {
    final source = WordRadarSource.withModel(
      FakeGenerativeModelClient('{"suggestions":[]}'),
    );

    final result = await source.scan(
      text: 'Short text.',
      targetLanguage: Language.english,
      targetCefrLevel: null,
      knownHeadwords: const [],
    );

    expect(result, isEmpty);
  });

  test('includes the known-headwords exclusion list in the prompt', () async {
    final client = FakeGenerativeModelClient('{"suggestions":[]}');
    final source = WordRadarSource.withModel(client);

    await source.scan(
      text: 'The cat sat on the mat.',
      targetLanguage: Language.english,
      targetCefrLevel: CEFRLevel.a1,
      knownHeadwords: const ['cat', 'mat'],
    );

    final part = client.lastPrompt!.first.parts.first as TextPart;
    expect(part.text, contains('cat'));
    expect(part.text, contains('mat'));
  });

  test('skips a malformed suggestion but keeps the valid ones in the same response', () async {
    final json = jsonEncode({
      'suggestions': [
        {
          'headword': 'ubiquitous',
          'ipa': '/juːˈbɪkwɪtəs/',
          'meaning': 'có mặt khắp nơi',
          'examples': <String>[],
          'suggestedTopics': <String>[],
        },
        {
          // missing 'headword' entirely — must not crash the whole batch
          'ipa': '/x/',
          'meaning': 'malformed item',
          'examples': <String>[],
          'suggestedTopics': <String>[],
        },
      ],
    });
    final source = WordRadarSource.withModel(FakeGenerativeModelClient(json));

    final result = await source.scan(
      text: 'Smartphones are everywhere now.',
      targetLanguage: Language.english,
      targetCefrLevel: null,
      knownHeadwords: const [],
    );

    expect(result, hasLength(1));
    expect(result[0].headword, 'ubiquitous');
  });
}
