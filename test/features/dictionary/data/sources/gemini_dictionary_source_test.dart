import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/data/sources/gemini_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';

/// Fake [GenerativeModelClient] that returns a canned response.
class FakeGenerativeModelClient implements GenerativeModelClient {
  FakeGenerativeModelClient(this._responseText);
  final String _responseText;

  @override
  Future<GenerateContentResponse> generateContent(
      Iterable<Content> prompt) async {
    return GenerateContentResponse(
      [Candidate(Content.text(_responseText), null, null, null, null)],
      null,
    );
  }
}

void main() {
  final wordJson = jsonEncode({
    'headword': 'follow up',
    'ipa': '/ˈfɒl.oʊ ʌp/',
    'meaning': 'Theo dõi hoặc liên hệ lại sau một sự kiện trước đó.',
    'examples': [
      'I will follow up with the client tomorrow.',
      'She sent a follow-up email after the meeting.',
    ],
    'suggestedTopics': ['Business'],
    'cefrLevel': 'b1',
  });

  test('parses word/phrase result from Gemini JSON', () async {
    final source = GeminiDictionarySource.withModel(
      FakeGenerativeModelClient(wordJson),
    );

    final result = await source.lookup(
      query: 'follow up',
      inputType: InputType.phrase,
      targetLanguage: Language.english,
    );

    expect(result, isA<WordPhraseResult>());
    final r = result as WordPhraseResult;
    expect(r.headword, 'follow up');
    expect(r.ipa, '/ˈfɒl.oʊ ʌp/');
    expect(r.inputType, InputType.phrase);
    expect(r.suggestedTopics, ['Business']);
    expect(r.cefrLevel, CEFRLevel.b1);
  });

  test('defaults cefrLevel to null when the AI response omits it', () async {
    final noLevelJson = jsonEncode({
      'headword': 'cat',
      'ipa': '/kæt/',
      'meaning': 'con mèo',
      'examples': <String>[],
      'suggestedTopics': <String>[],
    });
    final source = GeminiDictionarySource.withModel(
      FakeGenerativeModelClient(noLevelJson),
    );

    final result = await source.lookup(
      query: 'cat',
      inputType: InputType.word,
      targetLanguage: Language.english,
    );

    final r = result as WordPhraseResult;
    expect(r.cefrLevel, isNull);
  });

  test(
      'tolerates the AI returning a bare string instead of a one-item array for suggestedTopics',
      () async {
    // Real observed AI response shape: {"suggestedTopics": "Daily Life"}
    // instead of {"suggestedTopics": ["Daily Life"]} — must not crash the
    // lookup with a TypeError.
    final bareStringTopicJson = jsonEncode({
      'headword': 'commute',
      'ipa': '/kəˈmjuːt/',
      'meaning': 'di chuyển hàng ngày',
      'examples': ['I commute to work by train.'],
      'suggestedTopics': 'Daily Life',
    });
    final source = GeminiDictionarySource.withModel(
      FakeGenerativeModelClient(bareStringTopicJson),
    );

    final result = await source.lookup(
      query: 'commute',
      inputType: InputType.word,
      targetLanguage: Language.english,
    );

    final r = result as WordPhraseResult;
    expect(r.suggestedTopics, ['Daily Life']);
  });

  test('tolerates a bare string for examples and synonyms too', () async {
    final bareStringsJson = jsonEncode({
      'headword': 'run',
      'ipa': '/rʌn/',
      'meaning': 'chạy',
      'examples': 'He runs every morning.',
      'suggestedTopics': ['Sports'],
      'synonyms': 'jog',
    });
    final source = GeminiDictionarySource.withModel(
      FakeGenerativeModelClient(bareStringsJson),
    );

    final result = await source.lookup(
      query: 'run',
      inputType: InputType.word,
      targetLanguage: Language.english,
    );

    final r = result as WordPhraseResult;
    expect(r.examples, ['He runs every morning.']);
    expect(r.synonyms, ['jog']);
  });

  final sentenceJson = jsonEncode({
    'translation': 'Bạn có thể theo dõi với tôi không?',
  });

  test('parses sentence result from Gemini JSON', () async {
    final source = GeminiDictionarySource.withModel(
      FakeGenerativeModelClient(sentenceJson),
    );

    final result = await source.lookup(
      query: 'Can you follow up with me?',
      inputType: InputType.sentence,
      targetLanguage: Language.english,
    );

    expect(result, isA<SentenceResult>());
    final r = result as SentenceResult;
    expect(r.translation, 'Bạn có thể theo dõi với tôi không?');
    expect(r.original, 'Can you follow up with me?');
  });
}
