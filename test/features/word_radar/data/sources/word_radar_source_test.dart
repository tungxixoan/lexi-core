import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
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
  test('parses suggestions and translation from the AI JSON response', () async {
    final json = jsonEncode({
      'translation': 'Điện thoại thông minh có mặt khắp nơi hiện nay.',
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

    expect(result.translation, 'Điện thoại thông minh có mặt khắp nơi hiện nay.');
    expect(result.suggestions, hasLength(1));
    expect(result.suggestions[0].headword, 'ubiquitous');
    expect(result.suggestions[0].ipa, '/juːˈbɪkwɪtəs/');
    expect(result.suggestions[0].meaning, 'có mặt khắp nơi');
    expect(result.suggestions[0].definition, 'present, appearing, or found everywhere');
    expect(result.suggestions[0].synonyms, ['omnipresent', 'pervasive']);
    expect(result.suggestions[0].suggestedTopics, ['Technology']);
    expect(result.suggestions[0].cefrLevel, CEFRLevel.c1);
  });

  test('returns an empty suggestions list when the AI has nothing to suggest', () async {
    final source = WordRadarSource.withModel(
      FakeGenerativeModelClient('{"translation":"Văn bản ngắn.","suggestions":[]}'),
    );

    final result = await source.scan(
      text: 'Short text.',
      targetLanguage: Language.english,
      targetCefrLevel: null,
      knownHeadwords: const [],
    );

    expect(result.suggestions, isEmpty);
    expect(result.translation, 'Văn bản ngắn.');
  });

  test('defaults translation to an empty string when the AI omits it', () async {
    final source = WordRadarSource.withModel(
      FakeGenerativeModelClient('{"suggestions":[]}'),
    );

    final result = await source.scan(
      text: 'Short text.',
      targetLanguage: Language.english,
      targetCefrLevel: null,
      knownHeadwords: const [],
    );

    expect(result.translation, '');
  });

  test('includes the known-headwords exclusion list in the prompt', () async {
    final client = FakeGenerativeModelClient('{"translation":"","suggestions":[]}');
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
      'translation': '',
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

    expect(result.suggestions, hasLength(1));
    expect(result.suggestions[0].headword, 'ubiquitous');
  });

  test('classifies a multi-word suggestion as a phrase, not a word', () async {
    final json = jsonEncode({
      'translation': '',
      'suggestions': [
        {
          'headword': 'follow up',
          'ipa': '/ˈfɒl.oʊ ʌp/',
          'meaning': 'theo dõi',
          'examples': <String>[],
          'suggestedTopics': <String>[],
        },
      ],
    });
    final source = WordRadarSource.withModel(FakeGenerativeModelClient(json));

    final result = await source.scan(
      text: 'Please follow up with the client.',
      targetLanguage: Language.english,
      targetCefrLevel: null,
      knownHeadwords: const [],
    );

    expect(result.suggestions, hasLength(1));
    expect(result.suggestions[0].inputType, InputType.phrase);
  });

  test('defaults cefrLevel to null and keeps the suggestion when the AI returns an invalid level string', () async {
    final json = jsonEncode({
      'translation': '',
      'suggestions': [
        {
          'headword': 'ubiquitous',
          'ipa': '/juːˈbɪkwɪtəs/',
          'meaning': 'có mặt khắp nơi',
          'examples': <String>[],
          'suggestedTopics': <String>[],
          'cefrLevel': 'intermediate',
        },
      ],
    });
    final source = WordRadarSource.withModel(FakeGenerativeModelClient(json));

    final result = await source.scan(
      text: 'Smartphones are ubiquitous now.',
      targetLanguage: Language.english,
      targetCefrLevel: null,
      knownHeadwords: const [],
    );

    expect(result.suggestions, hasLength(1));
    expect(result.suggestions[0].headword, 'ubiquitous');
    expect(result.suggestions[0].cefrLevel, isNull);
  });

  test('treats a bare string as a single-item list when the AI returns one instead of a JSON array', () async {
    final json = jsonEncode({
      'translation': '',
      'suggestions': [
        {
          'headword': 'ubiquitous',
          'ipa': '/juːˈbɪkwɪtəs/',
          'meaning': 'có mặt khắp nơi',
          'examples': 'Smartphones are ubiquitous nowadays.',
          'suggestedTopics': 'Business',
          'synonyms': 'omnipresent',
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

    expect(result.suggestions, hasLength(1));
    expect(result.suggestions[0].examples, ['Smartphones are ubiquitous nowadays.']);
    expect(result.suggestions[0].suggestedTopics, ['Business']);
    expect(result.suggestions[0].synonyms, ['omnipresent']);
  });
}
