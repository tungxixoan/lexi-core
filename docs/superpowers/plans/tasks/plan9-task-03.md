# Plan 9 — Task 03: DictationSource + GenerateDictationItemUseCase

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 9 Task 02 (`DictationItem` defined)

## Global Constraints
(see `plan9-global-constraints.md`)

## What This Task Delivers
`DictationSource` calls the active AI provider once (via the shared `AiClientFactory`/`GenerativeModelClient`, exactly like `ReadingPassageSource` — never a hardcoded Gemini client) with a prompt asking for **one** medium-length sentence naturally using ~2 given vocabulary words, and parses the JSON response into a `DictationItem`. `GenerateDictationItemUseCase` wraps the source.

## Files
- Create: `lib/features/listening/data/sources/dictation_source.dart`
- Create: `lib/features/listening/domain/use_cases/generate_dictation_item_use_case.dart`
- Create: `test/features/listening/data/sources/dictation_source_test.dart`
- Create: `test/features/listening/domain/use_cases/generate_dictation_item_use_case_test.dart`

## Interfaces
- Consumes: `DictationItem` from Task 02; `VocabRecord`, `CEFRLevel`, `AppContext`, `Language`, `UserSettingsState` from existing code; `AiClientFactory`/`GenerativeModelClient` from `lib/core/services/ai_client_factory.dart`
- Produces:
  - `DictationSource(UserSettingsState settings)` — production constructor
  - `DictationSource.withModel(GenerativeModelClient client)` — for testing
  - `DictationSource.generate({required List<VocabRecord> words, required CEFRLevel level, required AppContext context, required Language targetLanguage}) → Future<DictationItem>`
  - `GenerateDictationItemUseCase(DictationSource source)`
  - `GenerateDictationItemUseCase.execute({required List<VocabRecord> words, required CEFRLevel level, required AppContext context, required Language targetLanguage}) → Future<DictationItem>`

## Steps

- [ ] **Step 1: Write the failing test for DictationSource**

Create `test/features/listening/data/sources/dictation_source_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/listening/data/sources/dictation_source.dart';

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
  ];

  final fakeJson = jsonEncode({
    'target': 'She showed remarkable perseverance in her work.',
    'vietnamese': 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.',
    'vocabWords': ['remarkable', 'perseverance'],
  });

  test('parses AI JSON into a DictationItem', () async {
    final source = DictationSource.withModel(
      FakeGenerativeModelClient(fakeJson),
    );
    final item = await source.generate(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );

    expect(item.target, 'She showed remarkable perseverance in her work.');
    expect(item.vietnamese, 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.');
    expect(item.vocabIds, containsAll(['id1', 'id2']));
    expect(item.level, CEFRLevel.b1);
    expect(item.context, AppContext.general);
    expect(item.targetLanguage, Language.english);
    expect(item.id, isNotEmpty);
  });

  test('vocabIds is empty when AI returns no vocabWords', () async {
    final emptyJson = jsonEncode({
      'target': 'Hello world.',
      'vietnamese': 'Xin chào thế giới.',
      'vocabWords': [],
    });
    final source = DictationSource.withModel(
      FakeGenerativeModelClient(emptyJson),
    );
    final item = await source.generate(
      words: words,
      level: CEFRLevel.a1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(item.vocabIds, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/data/sources/dictation_source_test.dart
```

Expected: FAIL — `dictation_source.dart` doesn't exist.

- [ ] **Step 3: Create DictationSource**

Create `lib/features/listening/data/sources/dictation_source.dart`:

```dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/dictation_item.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class DictationSource {
  DictationSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  DictationSource.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();

  Future<DictationItem> generate({
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
    final text = response.text ?? '{"target":"","vietnamese":"","vocabWords":[]}';
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
        'Write exactly one natural sentence of medium length (10 to 18 words) in '
        '${targetLanguage.label} at ${level.label} level. '
        'Context/register: ${context.label}. '
        'Naturally use these vocabulary words in the sentence: $wordList. '
        'Provide the sentence\'s Vietnamese translation and list which vocabulary '
        'words from the input actually appear in it. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"target": "the sentence in ${targetLanguage.label}", '
        '"vietnamese": "Vietnamese translation", '
        '"vocabWords": ["only words from the provided list that appear in this sentence"]}';
  }

  DictationItem _parse(
    Map<String, dynamic> json,
    Map<String, String> wordMap,
    CEFRLevel level,
    AppContext context,
    Language targetLanguage,
  ) {
    final vocabWords = List<String>.from(json['vocabWords'] as List? ?? []);
    final vocabIds =
        vocabWords.map((w) => wordMap[w]).whereType<String>().toList();

    return DictationItem(
      id: _uuid.v4(),
      target: json['target'] as String? ?? '',
      vietnamese: json['vietnamese'] as String? ?? '',
      vocabIds: vocabIds,
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
flutter test test/features/listening/data/sources/dictation_source_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Write the use case test**

Create `test/features/listening/domain/use_cases/generate_dictation_item_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/listening/data/sources/dictation_source.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/domain/use_cases/generate_dictation_item_use_case.dart';

class MockDictationSource extends Mock implements DictationSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(CEFRLevel.a1);
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
  });

  late MockDictationSource mockSource;
  late GenerateDictationItemUseCase useCase;

  setUp(() {
    mockSource = MockDictationSource();
    useCase = GenerateDictationItemUseCase(mockSource);
  });

  final words = List.generate(
    2,
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

  final fakeItem = DictationItem(
    id: 'fake-id',
    target: 'Hello world.',
    vietnamese: 'Xin chào thế giới.',
    vocabIds: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the item', () async {
    when(
      () => mockSource.generate(
        words: any(named: 'words'),
        level: any(named: 'level'),
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => fakeItem);

    final result = await useCase.execute(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(result, same(fakeItem));
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

Create `lib/features/listening/domain/use_cases/generate_dictation_item_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../data/sources/dictation_source.dart';
import '../entities/dictation_item.dart';

class GenerateDictationItemUseCase {
  const GenerateDictationItemUseCase(this._source);
  final DictationSource _source;

  Future<DictationItem> execute({
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

- [ ] **Step 7: Run all listening tests**

```bash
flutter test test/features/listening/
```

Expected: all tests pass.

- [ ] **Step 8: Analyze**

```bash
flutter analyze lib/features/listening/
```

Expected: no issues.

- [ ] **Step 9: Commit**

```bash
git add lib/features/listening/data/sources/dictation_source.dart \
        lib/features/listening/domain/use_cases/generate_dictation_item_use_case.dart \
        test/features/listening/data/sources/dictation_source_test.dart \
        test/features/listening/domain/use_cases/generate_dictation_item_use_case_test.dart
git commit -m "feat(plan9): add DictationSource + GenerateDictationItemUseCase"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
