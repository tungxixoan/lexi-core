# Task 7: Gemini Dictionary Source

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 2, 5

## Interfaces From Prior Tasks
- `InputType`, `AppContext`, `Language` from `lib/features/dictionary/domain/entities/`
- `LookupResult`, `WordPhraseResult`, `SentenceResult` from `lib/features/dictionary/domain/entities/lookup_result.dart`
- `DictionaryException` from `lib/features/dictionary/domain/repositories/dictionary_repository.dart`

## What This Task Delivers
Gemini Flash API client for AI-powered lookups. Supports word/phrase (returns `WordPhraseResult`) and sentence (returns `SentenceResult`). Also has `discoverWord` for the Discover feature.

Uses `google_generative_ai` package. Model: `gemini-2.5-flash`.

## Files
- Create: `lib/features/dictionary/data/sources/gemini_dictionary_source.dart`
- Create: `test/features/dictionary/data/sources/gemini_dictionary_source_test.dart`

## Produces (used by Tasks 8, 10)
```dart
class GeminiDictionarySource {
  GeminiDictionarySource({required String apiKey});
  GeminiDictionarySource.withModel(GenerativeModel model); // for testing

  Future<LookupResult> lookup({
    required String query,
    required InputType inputType,
    required Language targetLanguage,
    required AppContext context,
  });

  Future<String> discoverWord({
    required Language targetLanguage,
    required AppContext context,
  });
}
```

## Steps

- [ ] **Step 1: Write failing tests**

```dart
// test/features/dictionary/data/sources/gemini_dictionary_source_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/data/sources/gemini_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';

import 'gemini_dictionary_source_test.mocks.dart';

@GenerateMocks([GenerativeModel])
void main() {
  late MockGenerativeModel mockModel;
  late GeminiDictionarySource source;

  setUp(() {
    mockModel = MockGenerativeModel();
    source = GeminiDictionarySource.withModel(mockModel);
  });

  final wordJson = jsonEncode({
    'headword': 'follow up',
    'ipa': '/ˈfɒl.oʊ ʌp/',
    'meaning': 'Theo dõi hoặc liên hệ lại sau một sự kiện trước đó.',
    'examples': [
      'I will follow up with the client tomorrow.',
      'She sent a follow-up email after the meeting.',
    ],
    'suggestedTopics': ['Business'],
  });

  test('parses word/phrase result from Gemini JSON', () async {
    when(mockModel.generateContent(any)).thenAnswer(
      (_) async => GenerateContentResponse(
        [Candidate(Content.text(wordJson), null, null, null, null)],
        null,
      ),
    );

    final result = await source.lookup(
      query: 'follow up',
      inputType: InputType.phrase,
      targetLanguage: Language.english,
      context: AppContext.business,
    );

    expect(result, isA<WordPhraseResult>());
    final r = result as WordPhraseResult;
    expect(r.headword, 'follow up');
    expect(r.ipa, '/ˈfɒl.oʊ ʌp/');
    expect(r.inputType, InputType.phrase);
    expect(r.suggestedTopics, ['Business']);
  });

  final sentenceJson = jsonEncode({
    'translation': 'Bạn có thể theo dõi với tôi không?',
  });

  test('parses sentence result from Gemini JSON', () async {
    when(mockModel.generateContent(any)).thenAnswer(
      (_) async => GenerateContentResponse(
        [Candidate(Content.text(sentenceJson), null, null, null, null)],
        null,
      ),
    );

    final result = await source.lookup(
      query: 'Can you follow up with me?',
      inputType: InputType.sentence,
      targetLanguage: Language.english,
      context: AppContext.general,
    );

    expect(result, isA<SentenceResult>());
    final r = result as SentenceResult;
    expect(r.translation, 'Bạn có thể theo dõi với tôi không?');
    expect(r.original, 'Can you follow up with me?');
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run tests — expect FAIL**

```bash
flutter test test/features/dictionary/data/sources/gemini_dictionary_source_test.dart
```

Expected: compile error — `GeminiDictionarySource` not defined.

- [ ] **Step 4: Implement gemini_dictionary_source.dart**

```dart
// lib/features/dictionary/data/sources/gemini_dictionary_source.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/input_type.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/lookup_result.dart';

class GeminiDictionarySource {
  GeminiDictionarySource({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

  GeminiDictionarySource.withModel(this._model);

  final GenerativeModel _model;

  Future<LookupResult> lookup({
    required String query,
    required InputType inputType,
    required Language targetLanguage,
    required AppContext context,
  }) async {
    final prompt = inputType == InputType.sentence
        ? _sentencePrompt(query)
        : _wordPhrasePrompt(query, inputType, targetLanguage, context);

    final response = await _model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';
    final json = jsonDecode(text) as Map<String, dynamic>;

    if (inputType == InputType.sentence) {
      return SentenceResult(
        original: query,
        translation: json['translation'] as String,
      );
    }

    return WordPhraseResult(
      headword: json['headword'] as String,
      inputType: inputType,
      ipa: json['ipa'] as String,
      meaning: json['meaning'] as String,
      examples: (json['examples'] as List).cast<String>(),
      suggestedTopics: (json['suggestedTopics'] as List).cast<String>(),
    );
  }

  Future<String> discoverWord({
    required Language targetLanguage,
    required AppContext context,
  }) async {
    final prompt =
        'Suggest one ${targetLanguage.label} vocabulary word for an intermediate learner. '
        'Context: ${context.label}. '
        'Respond with JSON only: {"word": "the word"}';
    final response = await _model.generateContent([Content.text(prompt)]);
    final json = jsonDecode(response.text ?? '{}') as Map<String, dynamic>;
    return json['word'] as String;
  }

  String _wordPhrasePrompt(
    String query,
    InputType inputType,
    Language targetLanguage,
    AppContext context,
  ) =>
      'You are a language learning assistant helping a Vietnamese speaker learn ${targetLanguage.label}. '
      'Look up "$query" and respond with JSON only (no markdown, no code fences): '
      '{"headword":"exact word or phrase","ipa":"IPA transcription",'
      '"meaning":"Vietnamese definition",'
      '"examples":["example 1 in ${targetLanguage.label}","example 2"],'
      '"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"]} '
      'Shape examples for context: ${context.label}.';

  String _sentencePrompt(String sentence) =>
      'Translate this sentence to Vietnamese: "$sentence" '
      'Respond with JSON only: {"translation":"translated sentence"}';
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/features/dictionary/data/sources/gemini_dictionary_source_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dictionary/data/sources/gemini_dictionary_source.dart \
        test/features/dictionary/data/sources/gemini_dictionary_source_test.dart \
        test/features/dictionary/data/sources/gemini_dictionary_source_test.mocks.dart
git commit -m "feat: add GeminiDictionarySource for AI-powered lookup and discover"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed — `flutter test test/features/dictionary/data/sources/gemini_dictionary_source_test.dart`
Concerns: (if any)
