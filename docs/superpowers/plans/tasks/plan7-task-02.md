# Plan 7 — Task 02: ReadingPassageSource + GenerateReadingPassageUseCase

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 7 Task 01 (`ReadingPassage`, `BilingualSentence` defined)

## Global Constraints
(see `plan7-global-constraints.md`)

## What This Task Delivers
`ReadingPassageSource` calls Gemini once with a structured prompt and parses the JSON response into a `ReadingPassage`. It maps the Gemini-returned headword strings back to `VocabRecord.id` values so `BilingualSentence.vocabIds` contains actual IDs. `GenerateReadingPassageUseCase` wraps the source.

## Files
- Create: `lib/features/reading/data/sources/reading_passage_source.dart`
- Create: `lib/features/reading/domain/use_cases/generate_reading_passage_use_case.dart`
- Create: `test/features/reading/data/sources/reading_passage_source_test.dart`
- Create: `test/features/reading/domain/use_cases/generate_reading_passage_use_case_test.dart`

## Interfaces
- Consumes: `ReadingPassage`, `BilingualSentence` from Task 01; `VocabRecord`, `CEFRLevel`, `AppContext`, `Language` from existing code
- Produces:
  - `ReadingPassageSource({required String apiKey})`
  - `ReadingPassageSource.withModel(GenerativeModelClient client)` — for testing
  - `ReadingPassageSource.generate({required List<VocabRecord> words, required CEFRLevel level, required AppContext context, required Language targetLanguage}) → Future<ReadingPassage>`
  - `GenerateReadingPassageUseCase(ReadingPassageSource source)`
  - `GenerateReadingPassageUseCase.execute({required List<VocabRecord> words, required CEFRLevel level, required AppContext context, required Language targetLanguage}) → Future<ReadingPassage>`

## Steps

- [ ] **Step 1: Write the failing test for ReadingPassageSource**

Create `test/features/reading/data/sources/reading_passage_source_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/reading/data/sources/reading_passage_source.dart';

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

VocabRecord _makeRecord(String id, String headword) => VocabRecord(
      id: id,
      headword: headword,
      inputType: InputType.word,
      ipa: '',
      meaning: 'test meaning',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  final words = [
    _makeRecord('id1', 'perseverance'),
    _makeRecord('id2', 'remarkable'),
    _makeRecord('id3', 'endeavor'),
    _makeRecord('id4', 'accomplish'),
    _makeRecord('id5', 'challenge'),
  ];

  final fakeJson = jsonEncode({
    'sentences': [
      {
        'target': 'She showed remarkable perseverance in her work.',
        'vietnamese': 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.',
        'vocabWords': ['remarkable', 'perseverance'],
      },
      {
        'target': 'Every endeavor requires dedication.',
        'vietnamese': 'Mỗi nỗ lực đều cần sự cống hiến.',
        'vocabWords': ['endeavor'],
      },
      {
        'target': 'You can accomplish any challenge.',
        'vietnamese': 'Bạn có thể hoàn thành bất kỳ thử thách nào.',
        'vocabWords': ['accomplish', 'challenge'],
      },
    ],
  });

  test('parses Gemini JSON into a ReadingPassage', () async {
    final source = ReadingPassageSource.withModel(
      FakeGenerativeModelClient(fakeJson),
    );
    final passage = await source.generate(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );

    expect(passage.sentences.length, 3);
    expect(passage.sentences[0].target,
        'She showed remarkable perseverance in her work.');
    expect(passage.sentences[0].vocabIds, containsAll(['id1', 'id2']));
    expect(passage.sentences[1].vocabIds, ['id3']);
    expect(passage.sentences[2].vocabIds, containsAll(['id4', 'id5']));
    expect(passage.vocabIds, containsAll(['id1', 'id2', 'id3', 'id4', 'id5']));
    expect(passage.level, CEFRLevel.b1);
    expect(passage.targetLanguage, Language.english);
  });

  test('vocabIds are empty when Gemini returns no vocabWords', () async {
    final emptyJson = jsonEncode({
      'sentences': [
        {
          'target': 'Hello world.',
          'vietnamese': 'Xin chào.',
          'vocabWords': [],
        },
      ],
    });
    final source = ReadingPassageSource.withModel(
      FakeGenerativeModelClient(emptyJson),
    );
    final passage = await source.generate(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(passage.sentences[0].vocabIds, isEmpty);
    expect(passage.vocabIds, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/reading/data/sources/reading_passage_source_test.dart
```

Expected: FAIL — `reading_passage_source.dart` doesn't exist.

- [ ] **Step 3: Create ReadingPassageSource**

Create `lib/features/reading/data/sources/reading_passage_source.dart`:

```dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/reading_passage.dart';

abstract interface class GenerativeModelClient {
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt);
}

final class _RealModelClient implements GenerativeModelClient {
  _RealModelClient(this._model);
  final GenerativeModel _model;
  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) =>
      _model.generateContent(prompt);
}

class ReadingPassageSource {
  ReadingPassageSource({required String apiKey})
      : _client = _RealModelClient(
          GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
            ),
          ),
        );

  ReadingPassageSource.withModel(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();

  Future<ReadingPassage> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    final wordMap = {for (final w in words) w.headword: w.id};
    final prompt = _buildPrompt(
      headwords: wordMap.keys.toList(),
      level: level,
      context: context,
      targetLanguage: targetLanguage,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{}';
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _parse(json, wordMap, level, context, targetLanguage);
  }

  String _buildPrompt({
    required List<String> headwords,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) {
    final wordList = headwords.join(', ');
    return 'You are a language learning assistant helping a Vietnamese speaker learn '
        '${targetLanguage.label}. '
        'Write a short passage of 4 to 6 sentences in ${targetLanguage.label} at ${level.label} level. '
        'Context/register: ${context.label}. '
        'Naturally use as many of these vocabulary words as possible: $wordList. '
        'For each sentence, provide its Vietnamese translation and list which vocabulary words from the input appear in that sentence. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"sentences": [{"target": "sentence in ${targetLanguage.label}", '
        '"vietnamese": "Vietnamese translation", '
        '"vocabWords": ["only words from the provided list that appear in this sentence"]}]}';
  }

  ReadingPassage _parse(
    Map<String, dynamic> json,
    Map<String, String> wordMap,
    CEFRLevel level,
    AppContext context,
    Language targetLanguage,
  ) {
    final sentences = (json['sentences'] as List).map((s) {
      final sm = s as Map<String, dynamic>;
      final vocabWords = List<String>.from(sm['vocabWords'] as List? ?? []);
      final vocabIds =
          vocabWords.map((w) => wordMap[w]).whereType<String>().toList();
      return BilingualSentence(
        target: sm['target'] as String,
        vietnamese: sm['vietnamese'] as String,
        vocabIds: vocabIds,
      );
    }).toList();

    final allVocabIds =
        sentences.expand((s) => s.vocabIds).toSet().toList();

    return ReadingPassage(
      id: _uuid.v4(),
      sentences: sentences,
      vocabIds: allVocabIds,
      level: level,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Run the source test**

```bash
flutter test test/features/reading/data/sources/reading_passage_source_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Write the use case test**

Create `test/features/reading/domain/use_cases/generate_reading_passage_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/reading/data/sources/reading_passage_source.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_reading_passage_use_case.dart';

class MockReadingPassageSource extends Mock implements ReadingPassageSource {}

void main() {
  late MockReadingPassageSource mockSource;
  late GenerateReadingPassageUseCase useCase;

  setUp(() {
    mockSource = MockReadingPassageSource();
    useCase = GenerateReadingPassageUseCase(mockSource);
  });

  final words = List.generate(
    5,
    (i) => VocabRecord(
      id: 'id$i',
      headword: 'word$i',
      inputType: InputType.word,
      ipa: '',
      meaning: '',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  final fakePassage = ReadingPassage(
    id: 'fake-id',
    sentences: const [],
    vocabIds: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the passage', () async {
    when(
      () => mockSource.generate(
        words: any(named: 'words'),
        level: any(named: 'level'),
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => fakePassage);

    final result = await useCase.execute(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(result, same(fakePassage));
    verify(
      () => mockSource.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      ),
    ).called(1);
  });
}
```

- [ ] **Step 6: Create the use case**

Create `lib/features/reading/domain/use_cases/generate_reading_passage_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../data/sources/reading_passage_source.dart';
import '../entities/reading_passage.dart';

class GenerateReadingPassageUseCase {
  const GenerateReadingPassageUseCase(this._source);
  final ReadingPassageSource _source;

  Future<ReadingPassage> execute({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) =>
      _source.generate(
        words: words,
        level: level,
        context: context,
        targetLanguage: targetLanguage,
      );
}
```

- [ ] **Step 7: Run all reading tests**

```bash
flutter test test/features/reading/
```

Expected: all tests pass.

- [ ] **Step 8: Analyze**

```bash
flutter analyze lib/features/reading/
```

Expected: no issues.

- [ ] **Step 9: Commit**

```bash
git add lib/features/reading/data/sources/reading_passage_source.dart \
        lib/features/reading/domain/use_cases/generate_reading_passage_use_case.dart \
        test/features/reading/data/sources/reading_passage_source_test.dart \
        test/features/reading/domain/use_cases/generate_reading_passage_use_case_test.dart
git commit -m "feat(plan7): add ReadingPassageSource + GenerateReadingPassageUseCase"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
