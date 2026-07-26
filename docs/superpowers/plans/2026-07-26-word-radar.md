# Word Radar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Quét từ vựng" (Word Radar) screen — paste text, highlight words already in Vocab Bank for free, and get one AI call's worth of new-word suggestions (excluding what's already known) that save in one tap. Also fix a pre-existing bug: `SaveVocabSheet` hardcodes every saved word to `CEFRLevel.b1`.

**Architecture:** New top-level feature `lib/features/word_radar/` (Clean Architecture, mirrors `reading/`/`listening/`). Two independent pieces of Riverpod state — a fast local substring match against `VocabRepository`, and a single AI call via a new `WordRadarSource` — so the screen can render highlights immediately while suggestions are still loading. Suggestions reuse the existing `WordPhraseResult` entity and `SaveVocabSheet` widget unchanged.

**Tech Stack:** Flutter, Riverpod (`@riverpod` code generation), go_router, `google_generative_ai` via the existing `AiClientFactory`/`GenerativeModelClient` abstraction, `flutter_test` + `mocktail`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-26-word-radar-design.md` (commit dd489c1). Every task's requirements implicitly include this spec.
- One AI call per scan — never one call per suggested word.
- Highlighting uses plain case-insensitive substring matching — no tokenizer, no word-boundary logic. This is a deliberate simplification that already works for Chinese/Japanese (no spaces needed) and is an accepted trade-off for space-delimited languages, matching `reading_session_screen.dart`'s existing `_HighlightedText`.
- The highlighted-text renderer is a **second, separate, private copy** local to the new screen — do **not** extract a shared widget with Reading's `_HighlightedText`. This mirrors this codebase's established precedent of accepting near-identical duplication at 2 call sites (`_SpeedSelector`, `_ClozeInput`/`_ClozeResult`) over premature abstraction.
- New code lives under `lib/features/word_radar/`, **not** nested inside `lib/features/practice/` — same precedent as `reading/` and `listening/`, which are also reached only via a Practice-hub card yet are independent top-level features.
- Input is capped at 3000 characters via `TextField.maxLength` (Flutter enforces this on typed and pasted text alike, and renders the counter for free — no extra validation code needed).
- After every edit to a file containing `@riverpod`/`@Riverpod` annotations, run `dart run build_runner build --delete-conflicting-outputs` before running tests.
- Run `flutter analyze` and `flutter test` at the end of every task; both must be clean before committing.

---

## File Structure

```
lib/features/dictionary/domain/entities/lookup_result.dart          (modify — add cefrLevel)
lib/features/dictionary/data/sources/gemini_dictionary_source.dart  (modify — request/parse cefrLevel)
lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart  (modify — use AI cefrLevel when present)

lib/features/word_radar/
├── domain/
│   └── use_cases/
│       ├── find_known_headwords_use_case.dart      (new — local substring match)
│       └── generate_word_suggestions_use_case.dart (new — thin wrapper over WordRadarSource)
├── data/
│   └── sources/
│       └── word_radar_source.dart                  (new — AI call)
└── presentation/
    ├── providers/
    │   └── word_radar_provider.dart                (new — WordRadarState + WordRadarNotifier)
    └── screens/
        └── word_radar_screen.dart                  (new — UI)

lib/core/di/app_providers.dart          (modify — register 3 new providers, twice across tasks)
lib/core/router/app_router.dart         (modify — add /practice/radar route)
lib/features/practice/presentation/screens/practice_hub_screen.dart  (modify — add 5th card)
```

---

### Task 1: Fix hardcoded `CEFRLevel.b1` — use the AI-returned level when present

**Files:**
- Modify: `lib/features/dictionary/domain/entities/lookup_result.dart`
- Modify: `lib/features/dictionary/data/sources/gemini_dictionary_source.dart`
- Modify: `lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart`
- Test: `test/features/dictionary/data/sources/gemini_dictionary_source_test.dart` (extend)
- Test: `test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart` (new)

**Interfaces:**
- Produces: `WordPhraseResult.cefrLevel` (`CEFRLevel?`, default `null`) — consumed by Task 3's `WordRadarSource` and Task 5's `WordRadarScreen`.

- [ ] **Step 1: Write the failing tests**

Add a `cefrLevel` field to the `wordJson` fixture and two new assertions in the existing test, in `test/features/dictionary/data/sources/gemini_dictionary_source_test.dart`. Replace the whole file with:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/data/sources/gemini_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';

/// Fake [GenerativeModelClient] that returns a canned response.
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
      context: AppContext.business,
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
      context: AppContext.general,
    );

    final r = result as WordPhraseResult;
    expect(r.cefrLevel, isNull);
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
      context: AppContext.general,
    );

    expect(result, isA<SentenceResult>());
    final r = result as SentenceResult;
    expect(r.translation, 'Bạn có thể theo dõi với tôi không?');
    expect(r.original, 'Can you follow up with me?');
  });
}
```

Create `test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/save_vocab_sheet.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';

class _RecordingVocabRepository implements VocabRepository {
  VocabRecord? saved;

  @override
  Future<void> save(VocabRecord record) async {
    saved = record;
  }

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      [];

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async => false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async => null;

  @override
  Future<List<Topic>> getTopics() async => [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

Future<Widget> _buildSheet(WordPhraseResult result, _RecordingVocabRepository repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      vocabRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => SaveVocabSheet(result: result),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saves the AI-returned cefrLevel when present', (tester) async {
    final repo = _RecordingVocabRepository();
    const result = WordPhraseResult(
      headword: 'ubiquitous',
      inputType: InputType.word,
      ipa: '/juːˈbɪkwɪtəs/',
      meaning: 'có mặt khắp nơi',
      examples: [],
      suggestedTopics: [],
      cefrLevel: CEFRLevel.c1,
    );
    await tester.pumpWidget(await _buildSheet(result, repo));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to Vocab Bank'));
    await tester.pumpAndSettle();

    expect(repo.saved, isNotNull);
    expect(repo.saved!.cefrLevel, CEFRLevel.c1);
  });

  testWidgets('defaults to B1 when the result has no cefrLevel', (tester) async {
    final repo = _RecordingVocabRepository();
    const result = WordPhraseResult(
      headword: 'cat',
      inputType: InputType.word,
      ipa: '/kæt/',
      meaning: 'con mèo',
      examples: [],
      suggestedTopics: [],
    );
    await tester.pumpWidget(await _buildSheet(result, repo));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to Vocab Bank'));
    await tester.pumpAndSettle();

    expect(repo.saved, isNotNull);
    expect(repo.saved!.cefrLevel, CEFRLevel.b1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dictionary/data/sources/gemini_dictionary_source_test.dart test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart`
Expected: FAIL — `cefrLevel` is not a defined named parameter on `WordPhraseResult`, and `save_vocab_sheet_test.dart` fails to compile for the same reason (the file doesn't exist yet as a test target either, so this is really a "won't compile" failure, which counts as the required red step).

- [ ] **Step 3: Add `cefrLevel` to `WordPhraseResult`**

In `lib/features/dictionary/domain/entities/lookup_result.dart`, replace the whole file with:

```dart
// lib/features/dictionary/domain/entities/lookup_result.dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'input_type.dart';

sealed class LookupResult {
  const LookupResult();
}

final class WordPhraseResult extends LookupResult {
  const WordPhraseResult({
    required this.headword,
    required this.inputType,
    required this.ipa,
    required this.meaning,
    required this.examples,
    required this.suggestedTopics,
    this.definition = '',
    this.synonyms = const [],
    this.cefrLevel,
  });

  final String headword;
  final InputType inputType; // word or phrase only — never sentence
  final String ipa;
  final String meaning;
  final List<String> examples;
  final List<String> suggestedTopics;
  final String definition; // English definition (optional)
  final List<String> synonyms;
  final CEFRLevel? cefrLevel; // AI-sourced level, when available

}

final class SentenceResult extends LookupResult {
  const SentenceResult({
    required this.original,
    required this.translation,
  });

  final String original;
  final String translation;
}
```

- [ ] **Step 4: Request and parse `cefrLevel` in `GeminiDictionarySource`**

In `lib/features/dictionary/data/sources/gemini_dictionary_source.dart`, add the import and update both the JSON-parsing site and the prompt string.

Add this import alongside the existing ones (after `import '../../domain/entities/language.dart';`):

```dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
```

Replace the `lookup()` method's `WordPhraseResult(...)` construction:

```dart
    return WordPhraseResult(
      headword: json['headword'] as String,
      inputType: inputType,
      ipa: json['ipa'] as String,
      meaning: json['meaning'] as String,
      examples: (json['examples'] as List).cast<String>(),
      suggestedTopics: (json['suggestedTopics'] as List).cast<String>(),
      definition: json['definition'] as String? ?? '',
      synonyms: (json['synonyms'] as List?)?.cast<String>() ?? const [],
      cefrLevel: json['cefrLevel'] != null
          ? CEFRLevel.values.byName((json['cefrLevel'] as String).toLowerCase())
          : null,
    );
```

Replace the `_wordPhrasePrompt` method body:

```dart
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
      '"definition":"English definition",'
      '"synonyms":["2-4 English synonyms for this sense, or empty array if none fit"],'
      '"examples":["example 1 in ${targetLanguage.label}","example 2"],'
      '"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"],'
      '"cefrLevel":"a1, a2, b1, b2, c1, or c2 — the CEFR difficulty level of this word or phrase"} '
      'If the word has multiple common parts of speech (e.g. "record" as both noun and verb), '
      'cover each sense in both "meaning" and "definition" using this format: "(n) ...; (v) ...", '
      'and give an IPA per sense too, e.g. "N: /ˈrekɔːrd/; V: /rɪˈkɔːrd/". '
      'Shape examples for context: ${context.label}.';
```

- [ ] **Step 5: Use the AI-returned level in `SaveVocabSheet`**

In `lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart`, in `_save()`, change:

```dart
      cefrLevel: CEFRLevel.b1,
```

to:

```dart
      cefrLevel: widget.result.cefrLevel ?? CEFRLevel.b1,
```

- [ ] **Step 6: Regenerate code and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/dictionary/data/sources/gemini_dictionary_source_test.dart test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart`
Expected: PASS — 5/5 tests (3 in `gemini_dictionary_source_test.dart`, 2 in `save_vocab_sheet_test.dart`).

Run: `flutter test`
Expected: PASS — full suite green (this touches a widely-used entity, so confirm nothing else broke).

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dictionary/domain/entities/lookup_result.dart lib/features/dictionary/data/sources/gemini_dictionary_source.dart lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart test/features/dictionary/data/sources/gemini_dictionary_source_test.dart test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart
git commit -m "fix(dictionary): use AI-returned CEFR level when saving, default B1 otherwise"
```

---

### Task 2: `FindKnownHeadwordsUseCase`

**Files:**
- Create: `lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart`
- Modify: `lib/core/di/app_providers.dart`
- Test: `test/features/word_radar/domain/use_cases/find_known_headwords_use_case_test.dart`

**Interfaces:**
- Produces: `FindKnownHeadwordsUseCase.execute({required String text, required Language language}) -> Future<List<String>>`, and `findKnownHeadwordsUseCaseProvider` — consumed by Task 4's `WordRadarNotifier`.

- [ ] **Step 1: Write the failing test**

Create `test/features/word_radar/domain/use_cases/find_known_headwords_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart';

VocabRecord _record(String headword, {Language language = Language.english}) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: headword,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: 'meaning of $headword',
    examples: const [],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: language,
    cefrLevel: CEFRLevel.a1,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      language == null
          ? records
          : records.where((r) => r.targetLanguage == language).toList();

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async => false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async => null;

  @override
  Future<List<Topic>> getTopics() async => [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

void main() {
  test('finds a headword that appears as a substring in the text', () async {
    final repo = _FakeVocabRepository([_record('serendipity')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'It was pure serendipity that we met.',
      language: Language.english,
    );

    expect(result, ['serendipity']);
  });

  test('matches case-insensitively', () async {
    final repo = _FakeVocabRepository([_record('Hello')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'hello there, how are you?',
      language: Language.english,
    );

    expect(result, ['Hello']);
  });

  test('returns no duplicates when a headword appears multiple times', () async {
    final repo = _FakeVocabRepository([_record('cat')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'The cat sat near another cat.',
      language: Language.english,
    );

    expect(result, ['cat']);
  });

  test('matches Chinese headwords with no spaces around them', () async {
    final repo = _FakeVocabRepository([
      _record('你好', language: Language.chinese),
    ]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: '今天你好吗',
      language: Language.chinese,
    );

    expect(result, ['你好']);
  });

  test('excludes headwords that do not appear in the text', () async {
    final repo = _FakeVocabRepository([_record('elephant')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'This text has nothing to do with animals.',
      language: Language.english,
    );

    expect(result, isEmpty);
  });

  test('returns an empty list when the Vocab Bank has no records', () async {
    final repo = _FakeVocabRepository(const []);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'Any text at all.',
      language: Language.english,
    );

    expect(result, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/word_radar/domain/use_cases/find_known_headwords_use_case_test.dart`
Expected: FAIL — `find_known_headwords_use_case.dart` does not exist (import error).

- [ ] **Step 3: Write the implementation**

Create `lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/repositories/vocab_repository.dart';

class FindKnownHeadwordsUseCase {
  const FindKnownHeadwordsUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<String>> execute({
    required String text,
    required Language language,
  }) async {
    final records = await _repo.getAll(language: language);
    final lowerText = text.toLowerCase();
    final matches = <String>{};
    for (final record in records) {
      if (lowerText.contains(record.headword.toLowerCase())) {
        matches.add(record.headword);
      }
    }
    return matches.toList();
  }
}
```

- [ ] **Step 4: Register the DI provider**

In `lib/core/di/app_providers.dart`, add this import near the other feature-grouped imports (after the Listening DI block):

```dart
// --- Word Radar DI ---
import '../../features/word_radar/domain/use_cases/find_known_headwords_use_case.dart';
```

Add this provider at the end of the file:

```dart

@riverpod
FindKnownHeadwordsUseCase findKnownHeadwordsUseCase(
        FindKnownHeadwordsUseCaseRef ref) =>
    FindKnownHeadwordsUseCase(ref.watch(vocabRepositoryProvider));
```

- [ ] **Step 5: Regenerate code and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/word_radar/domain/use_cases/find_known_headwords_use_case_test.dart`
Expected: PASS — 6/6 tests.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart test/features/word_radar/domain/use_cases/find_known_headwords_use_case_test.dart
git commit -m "feat(word-radar): add FindKnownHeadwordsUseCase (local substring match)"
```

---

### Task 3: `WordRadarSource` + `GenerateWordSuggestionsUseCase`

**Files:**
- Create: `lib/features/word_radar/data/sources/word_radar_source.dart`
- Create: `lib/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart`
- Modify: `lib/core/di/app_providers.dart`
- Test: `test/features/word_radar/data/sources/word_radar_source_test.dart`
- Test: `test/features/word_radar/domain/use_cases/generate_word_suggestions_use_case_test.dart`

**Interfaces:**
- Consumes: `WordPhraseResult` (Task 1, now with `cefrLevel`).
- Produces: `WordRadarSource.withModel(GenerativeModelClient)` / `WordRadarSource(UserSettingsState)`, `WordRadarSource.scan({required String text, required Language targetLanguage, required CEFRLevel? targetCefrLevel, required List<String> knownHeadwords}) -> Future<List<WordPhraseResult>>`; `GenerateWordSuggestionsUseCase.execute(...)` with the same parameters; `generateWordSuggestionsUseCaseProvider` — consumed by Task 4's `WordRadarNotifier`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/word_radar/data/sources/word_radar_source_test.dart`:

```dart
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
}
```

Create `test/features/word_radar/domain/use_cases/generate_word_suggestions_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/word_radar/data/sources/word_radar_source.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart';

class MockWordRadarSource extends Mock implements WordRadarSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.a1);
  });

  late MockWordRadarSource mockSource;
  late GenerateWordSuggestionsUseCase useCase;

  setUp(() {
    mockSource = MockWordRadarSource();
    useCase = GenerateWordSuggestionsUseCase(mockSource);
  });

  const fakeSuggestions = [
    WordPhraseResult(
      headword: 'ubiquitous',
      inputType: InputType.word,
      ipa: '/juːˈbɪkwɪtəs/',
      meaning: 'có mặt khắp nơi',
      examples: [],
      suggestedTopics: [],
      cefrLevel: CEFRLevel.c1,
    ),
  ];

  test('delegates to source.scan() and returns its suggestions', () async {
    when(
      () => mockSource.scan(
        text: any(named: 'text'),
        targetLanguage: any(named: 'targetLanguage'),
        targetCefrLevel: any(named: 'targetCefrLevel'),
        knownHeadwords: any(named: 'knownHeadwords'),
      ),
    ).thenAnswer((_) async => fakeSuggestions);

    final result = await useCase.execute(
      text: 'Smartphones are everywhere now.',
      targetLanguage: Language.english,
      targetCefrLevel: CEFRLevel.c1,
      knownHeadwords: const ['phone'],
    );

    expect(result, same(fakeSuggestions));
    verify(
      () => mockSource.scan(
        text: 'Smartphones are everywhere now.',
        targetLanguage: Language.english,
        targetCefrLevel: CEFRLevel.c1,
        knownHeadwords: const ['phone'],
      ),
    ).called(1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/word_radar/data/sources/word_radar_source_test.dart test/features/word_radar/domain/use_cases/generate_word_suggestions_use_case_test.dart`
Expected: FAIL — `word_radar_source.dart` and `generate_word_suggestions_use_case.dart` do not exist (import errors).

- [ ] **Step 3: Write `WordRadarSource`**

Create `lib/features/word_radar/data/sources/word_radar_source.dart`:

```dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../../../core/services/ai_client_factory.dart';
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class WordRadarSource {
  WordRadarSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  WordRadarSource.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;

  Future<List<WordPhraseResult>> scan({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
    required List<String> knownHeadwords,
  }) async {
    final prompt = _buildPrompt(
      text: text,
      targetLanguage: targetLanguage,
      targetCefrLevel: targetCefrLevel,
      knownHeadwords: knownHeadwords,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final responseText = response.text ?? '{"suggestions":[]}';
    final json = jsonDecode(responseText) as Map<String, dynamic>;
    return (json['suggestions'] as List? ?? [])
        .map((item) => _parseSuggestion(item as Map<String, dynamic>))
        .toList();
  }

  String _buildPrompt({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
    required List<String> knownHeadwords,
  }) {
    final levelClause =
        targetCefrLevel != null ? 'at ${targetCefrLevel.label} level' : 'at any level';
    final exclusionClause = knownHeadwords.isEmpty
        ? 'There are no already-known words to exclude.'
        : 'Do NOT suggest any of these already-known words: ${knownHeadwords.join(", ")}.';
    return 'You are a language learning assistant helping a Vietnamese speaker learn '
        '${targetLanguage.label}. Given this text: "$text", suggest up to 10 words or '
        'short phrases from the text that are worth learning $levelClause, for a '
        'Vietnamese speaker. $exclusionClause '
        'Respond with JSON only (no markdown, no code fences): '
        '{"suggestions":[{"headword":"exact word or phrase from the text",'
        '"ipa":"IPA transcription","meaning":"Vietnamese definition",'
        '"definition":"English definition",'
        '"synonyms":["2-4 English synonyms, or empty array if none fit"],'
        '"examples":["one example sentence, ideally reusing context from the source text"],'
        '"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, '
        'Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, '
        'Phrasal Verbs, Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"],'
        '"cefrLevel":"a1, a2, b1, b2, c1, or c2"}]}. '
        'If nothing in the text is worth learning, respond with {"suggestions":[]}.';
  }

  WordPhraseResult _parseSuggestion(Map<String, dynamic> json) => WordPhraseResult(
        headword: json['headword'] as String,
        inputType: InputType.word,
        ipa: json['ipa'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        examples: (json['examples'] as List?)?.cast<String>() ?? const [],
        suggestedTopics: (json['suggestedTopics'] as List?)?.cast<String>() ?? const [],
        definition: json['definition'] as String? ?? '',
        synonyms: (json['synonyms'] as List?)?.cast<String>() ?? const [],
        cefrLevel: json['cefrLevel'] != null
            ? CEFRLevel.values.byName((json['cefrLevel'] as String).toLowerCase())
            : null,
      );
}
```

- [ ] **Step 4: Write `GenerateWordSuggestionsUseCase`**

Create `lib/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/word_radar_source.dart';

class GenerateWordSuggestionsUseCase {
  const GenerateWordSuggestionsUseCase(this._source);
  final WordRadarSource _source;

  Future<List<WordPhraseResult>> execute({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
    required List<String> knownHeadwords,
  }) =>
      _source.scan(
        text: text,
        targetLanguage: targetLanguage,
        targetCefrLevel: targetCefrLevel,
        knownHeadwords: knownHeadwords,
      );
}
```

- [ ] **Step 5: Register the DI providers**

In `lib/core/di/app_providers.dart`, extend the Word Radar import block:

```dart
// --- Word Radar DI ---
import '../../features/word_radar/data/sources/word_radar_source.dart';
import '../../features/word_radar/domain/use_cases/find_known_headwords_use_case.dart';
import '../../features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart';
```

Add these providers at the end of the file:

```dart

@riverpod
WordRadarSource wordRadarSource(WordRadarSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return WordRadarSource(settings);
}

@riverpod
GenerateWordSuggestionsUseCase generateWordSuggestionsUseCase(
        GenerateWordSuggestionsUseCaseRef ref) =>
    GenerateWordSuggestionsUseCase(ref.watch(wordRadarSourceProvider));
```

- [ ] **Step 6: Regenerate code and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/word_radar/`
Expected: PASS — 3 tests in `word_radar_source_test.dart` + 1 in `generate_word_suggestions_use_case_test.dart` + the 6 from Task 2 = 10/10.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/word_radar/data/sources/word_radar_source.dart lib/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart test/features/word_radar/data/sources/word_radar_source_test.dart test/features/word_radar/domain/use_cases/generate_word_suggestions_use_case_test.dart
git commit -m "feat(word-radar): add WordRadarSource + GenerateWordSuggestionsUseCase"
```

---

### Task 4: `WordRadarNotifier`

**Files:**
- Create: `lib/features/word_radar/presentation/providers/word_radar_provider.dart`
- Test: `test/features/word_radar/presentation/providers/word_radar_provider_test.dart`

**Interfaces:**
- Consumes: `findKnownHeadwordsUseCaseProvider`, `generateWordSuggestionsUseCaseProvider` (Tasks 2 & 3), `userSettingsNotifierProvider` (existing).
- Produces: `WordRadarState { List<String>? knownHeadwords; AsyncValue<List<WordPhraseResult>>? suggestions; }`, `wordRadarNotifierProvider` with methods `scan(String text)`, `retrySuggestions(String text)`, `reset()` — consumed by Task 5's `WordRadarScreen`.

- [ ] **Step 1: Write the failing test**

Create `test/features/word_radar/presentation/providers/word_radar_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/word_radar/presentation/providers/word_radar_provider.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

VocabRecord _record(String headword) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: headword,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: 'meaning of $headword',
    examples: const [],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: Language.english,
    cefrLevel: CEFRLevel.a1,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async => false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async => null;

  @override
  Future<List<Topic>> getTopics() async => [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

Future<ProviderContainer> _makeContainer({
  required bool aiEnabled,
  required List<VocabRecord> vocabItems,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(
          UserSettingsState.defaults.copyWith(aiEnabled: aiEnabled),
        ),
      ),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(vocabItems)),
    ],
  );
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('populates knownHeadwords and leaves suggestions null when AI is disabled', () async {
    final container = await _makeContainer(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    );
    addTearDown(container.dispose);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');

    final state = container.read(wordRadarNotifierProvider);
    expect(state.knownHeadwords, ['serendipity']);
    expect(state.suggestions, isNull);
  });

  test('leaves knownHeadwords empty when nothing in the Vocab Bank matches', () async {
    final container = await _makeContainer(aiEnabled: false, vocabItems: const []);
    addTearDown(container.dispose);

    await container.read(wordRadarNotifierProvider.notifier).scan('Some text.');

    final state = container.read(wordRadarNotifierProvider);
    expect(state.knownHeadwords, isEmpty);
  });

  test('reset() clears back to the initial state', () async {
    final container = await _makeContainer(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    );
    addTearDown(container.dispose);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');
    container.read(wordRadarNotifierProvider.notifier).reset();

    final state = container.read(wordRadarNotifierProvider);
    expect(state.knownHeadwords, isNull);
    expect(state.suggestions, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/word_radar/presentation/providers/word_radar_provider_test.dart`
Expected: FAIL — `word_radar_provider.dart` does not exist (import error).

- [ ] **Step 3: Write the implementation**

Create `lib/features/word_radar/presentation/providers/word_radar_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';

part 'word_radar_provider.g.dart';

final class WordRadarState {
  const WordRadarState({this.knownHeadwords, this.suggestions});

  final List<String>? knownHeadwords; // null = not scanned yet
  final AsyncValue<List<WordPhraseResult>>? suggestions; // null = AI not run

  WordRadarState copyWith({
    List<String>? knownHeadwords,
    AsyncValue<List<WordPhraseResult>>? suggestions,
  }) =>
      WordRadarState(
        knownHeadwords: knownHeadwords ?? this.knownHeadwords,
        suggestions: suggestions ?? this.suggestions,
      );
}

@riverpod
class WordRadarNotifier extends _$WordRadarNotifier {
  @override
  WordRadarState build() => const WordRadarState();

  Future<void> scan(String text) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final knownHeadwords = await ref
        .read(findKnownHeadwordsUseCaseProvider)
        .execute(text: text, language: settings.targetLanguage);

    if (!settings.aiEnabled) {
      state = WordRadarState(knownHeadwords: knownHeadwords, suggestions: null);
      return;
    }

    state = WordRadarState(
      knownHeadwords: knownHeadwords,
      suggestions: const AsyncLoading(),
    );
    final suggestions = await AsyncValue.guard(
      () => ref.read(generateWordSuggestionsUseCaseProvider).execute(
            text: text,
            targetLanguage: settings.targetLanguage,
            targetCefrLevel: settings.targetCefrLevel,
            knownHeadwords: knownHeadwords,
          ),
    );
    state = state.copyWith(suggestions: suggestions);
  }

  Future<void> retrySuggestions(String text) async {
    final current = state;
    if (current.knownHeadwords == null) return;
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.aiEnabled) return;
    state = current.copyWith(suggestions: const AsyncLoading());
    final suggestions = await AsyncValue.guard(
      () => ref.read(generateWordSuggestionsUseCaseProvider).execute(
            text: text,
            targetLanguage: settings.targetLanguage,
            targetCefrLevel: settings.targetCefrLevel,
            knownHeadwords: current.knownHeadwords!,
          ),
    );
    state = state.copyWith(suggestions: suggestions);
  }

  void reset() => state = const WordRadarState();
}
```

- [ ] **Step 4: Regenerate code and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/word_radar/`
Expected: PASS — 3 new tests + 10 from Tasks 2–3 = 13/13.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/word_radar/presentation/providers/word_radar_provider.dart lib/features/word_radar/presentation/providers/word_radar_provider.g.dart test/features/word_radar/presentation/providers/word_radar_provider_test.dart
git commit -m "feat(word-radar): add WordRadarNotifier (two-stage local + AI state)"
```

---

### Task 5: `WordRadarScreen`

**Files:**
- Create: `lib/features/word_radar/presentation/screens/word_radar_screen.dart`
- Test: `test/features/word_radar/presentation/screens/word_radar_screen_test.dart`

**Interfaces:**
- Consumes: `wordRadarNotifierProvider` (Task 4), `SaveVocabSheet` (existing, unmodified), `vocabRepositoryProvider`/`userSettingsNotifierProvider` (existing), go_router routes `/practice` and `/vocab/:id` (existing) and `/practice/radar` (added in Task 6).

- [ ] **Step 1: Write the failing test**

Create `test/features/word_radar/presentation/screens/word_radar_screen_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/word_radar/data/sources/word_radar_source.dart';
import 'package:lexi_core/features/word_radar/presentation/screens/word_radar_screen.dart';

class _FakeGenerativeModelClient implements GenerativeModelClient {
  _FakeGenerativeModelClient(this._responseText);
  final String _responseText;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    return GenerateContentResponse(
      [Candidate(Content.text(_responseText), null, null, null, null)],
      null,
    );
  }
}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

VocabRecord _record(String headword) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: headword,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: 'meaning of $headword',
    examples: const [],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: Language.english,
    cefrLevel: CEFRLevel.a1,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async => false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async {
    for (final r in records) {
      if (r.headword == headword) return r;
    }
    return null;
  }

  @override
  Future<List<Topic>> getTopics() async => [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

Future<Widget> _buildScreen({
  required bool aiEnabled,
  required List<VocabRecord> vocabItems,
  WordRadarSource? source,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const WordRadarScreen()),
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice hub')),
      ),
      GoRoute(
        path: '/vocab/:id',
        builder: (ctx, state) => Scaffold(
          body: Text('Vocab detail ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(
          UserSettingsState.defaults.copyWith(aiEnabled: aiEnabled),
        ),
      ),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(vocabItems)),
      if (source != null) wordRadarSourceProvider.overrideWithValue(source),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the AI-disabled note after scanning with AI off', (tester) async {
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'It was pure serendipity.');
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bật AI trong Cài đặt'), findsOneWidget);
  });

  testWidgets('tapping a highlighted known word navigates to its detail screen',
      (tester) async {
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'It was pure serendipity.');
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('serendipity'));
    await tester.pumpAndSettle();

    expect(find.text('Vocab detail serendipity'), findsOneWidget);
  });

  testWidgets('shows a suggestion card with a Lưu button when AI is enabled',
      (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient(jsonEncode({
        'suggestions': [
          {
            'headword': 'ubiquitous',
            'ipa': '/juːˈbɪkwɪtəs/',
            'meaning': 'có mặt khắp nơi',
            'examples': <String>[],
            'suggestedTopics': <String>[],
          },
        ],
      })),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: const [],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Some text here.');
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsOneWidget);
    expect(find.text('Lưu'), findsOneWidget);
  });

  testWidgets('shows "Không có gợi ý mới" when AI returns no suggestions',
      (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient('{"suggestions":[]}'),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: const [],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Some text here.');
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });

  testWidgets('the Quét button is disabled while the input is empty', (tester) async {
    await tester.pumpWidget(await _buildScreen(aiEnabled: false, vocabItems: const []));
    await tester.pumpAndSettle();

    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Quét'));
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/word_radar/presentation/screens/word_radar_screen_test.dart`
Expected: FAIL — `word_radar_screen.dart` does not exist (import error).

- [ ] **Step 3: Write the implementation**

Create `lib/features/word_radar/presentation/screens/word_radar_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../dictionary/presentation/widgets/save_vocab_sheet.dart';
import '../providers/word_radar_provider.dart';

const _maxInputLength = 3000;

class WordRadarScreen extends ConsumerStatefulWidget {
  const WordRadarScreen({super.key});

  @override
  ConsumerState<WordRadarScreen> createState() => _WordRadarScreenState();
}

class _WordRadarScreenState extends ConsumerState<WordRadarScreen> {
  final _controller = TextEditingController();
  final Set<String> _savedHeadwords = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() {
    return ref.read(wordRadarNotifierProvider.notifier).scan(_controller.text);
  }

  Future<void> _openSaveSheet(WordPhraseResult suggestion) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaveVocabSheet(result: suggestion),
    );
    if (saved == true) {
      setState(() => _savedHeadwords.add(suggestion.headword));
    }
  }

  Future<void> _openKnownWord(String headword) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final repo = ref.read(vocabRepositoryProvider);
    final record = await repo.getByHeadword(headword, settings.targetLanguage);
    if (record != null && mounted) {
      context.push('/vocab/${record.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(wordRadarNotifierProvider);
    final theme = Theme.of(context);
    final textLength = _controller.text.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét từ vựng'),
        leading: BackButton(onPressed: () => context.go('/practice')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            maxLines: 8,
            maxLength: _maxInputLength,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Dán văn bản vào đây...',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: textLength == 0 ? null : _scan,
              child: const Text('Quét'),
            ),
          ),
          const SizedBox(height: 24),
          if (radarState.knownHeadwords != null) ...[
            Text('Văn bản', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _HighlightedText(
              text: _controller.text,
              highlights: radarState.knownHeadwords!,
              onTapHighlight: _openKnownWord,
            ),
            const SizedBox(height: 24),
            Text('Gợi ý từ mới', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _buildSuggestions(radarState),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestions(WordRadarState radarState) {
    final suggestions = radarState.suggestions;
    if (suggestions == null) {
      return const Text('Bật AI trong Cài đặt để nhận gợi ý từ mới.');
    }
    return suggestions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Không tải được gợi ý: $e'),
          TextButton(
            onPressed: () => ref
                .read(wordRadarNotifierProvider.notifier)
                .retrySuggestions(_controller.text),
            child: const Text('Thử lại'),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) return const Text('Không có gợi ý mới.');
        return Column(
          children: list
              .map(
                (s) => Card(
                  child: ListTile(
                    title: Text(s.headword),
                    subtitle: Text('${s.ipa}  •  ${s.meaning}'),
                    trailing: _savedHeadwords.contains(s.headword)
                        ? const Text('Đã lưu')
                        : TextButton(
                            onPressed: () => _openSaveSheet(s),
                            child: const Text('Lưu'),
                          ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlights,
    required this.onTapHighlight,
  });

  final String text;
  final List<String> highlights;
  final void Function(String headword) onTapHighlight;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty || text.isEmpty) {
      return Text(text);
    }
    const highlightStyle = TextStyle(
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
    );
    final spans = <InlineSpan>[];
    String remaining = text;
    while (remaining.isNotEmpty) {
      int? earliestStart;
      String? earliestWord;
      for (final word in highlights) {
        if (word.isEmpty) continue;
        final idx = remaining.toLowerCase().indexOf(word.toLowerCase());
        if (idx >= 0 && (earliestStart == null || idx < earliestStart)) {
          earliestStart = idx;
          earliestWord = word;
        }
      }
      if (earliestStart == null || earliestWord == null) {
        spans.add(TextSpan(text: remaining));
        break;
      }
      if (earliestStart > 0) {
        spans.add(TextSpan(text: remaining.substring(0, earliestStart)));
      }
      final matchedText =
          remaining.substring(earliestStart, earliestStart + earliestWord.length);
      final tappedWord = earliestWord;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => onTapHighlight(tappedWord),
          child: Text(matchedText, style: highlightStyle),
        ),
      ));
      remaining = remaining.substring(earliestStart + earliestWord.length);
    }
    return Text.rich(TextSpan(children: spans));
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/word_radar/`
Expected: PASS — 5 new tests + 13 from Tasks 2–4 = 18/18.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/word_radar/presentation/screens/word_radar_screen.dart test/features/word_radar/presentation/screens/word_radar_screen_test.dart
git commit -m "feat(word-radar): add WordRadarScreen UI"
```

---

### Task 6: Wire the route and the Practice-hub card

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/practice/presentation/screens/practice_hub_screen.dart`
- Test: `test/features/practice/presentation/screens/practice_hub_screen_test.dart` (new)

**Interfaces:**
- Consumes: `WordRadarScreen` (Task 5).

- [ ] **Step 1: Write the failing test**

Create `test/features/practice/presentation/screens/practice_hub_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/practice/presentation/screens/practice_hub_screen.dart';

Widget _buildHub() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const PracticeHubScreen()),
      GoRoute(
        path: '/practice/vocab',
        builder: (ctx, state) => const Scaffold(body: Text('Vocab practice home')),
      ),
      GoRoute(
        path: '/reading',
        builder: (ctx, state) => const Scaffold(body: Text('Reading home')),
      ),
      GoRoute(
        path: '/listening',
        builder: (ctx, state) => const Scaffold(body: Text('Listening home')),
      ),
      GoRoute(
        path: '/practice/progress',
        builder: (ctx, state) => const Scaffold(body: Text('Progress screen')),
      ),
      GoRoute(
        path: '/practice/radar',
        builder: (ctx, state) => const Scaffold(body: Text('Word Radar screen')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows all 5 hub cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Từ vựng cách khoảng'), findsOneWidget);
    expect(find.text('Đọc & gõ'), findsOneWidget);
    expect(find.text('Luyện nghe'), findsOneWidget);
    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(find.text('Quét từ vựng'), findsOneWidget);
  });

  testWidgets('tapping Quét từ vựng navigates to /practice/radar', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quét từ vựng'));
    await tester.pumpAndSettle();
    expect(find.text('Word Radar screen'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/practice/presentation/screens/practice_hub_screen_test.dart`
Expected: FAIL — the second test fails because `/practice/radar` is never navigated to (no "Quét từ vựng" card exists yet); the first test fails on `find.text('Quét từ vựng')` finding nothing.

- [ ] **Step 3: Add the route**

In `lib/core/router/app_router.dart`, add this import alongside the other Practice-related imports:

```dart
import '../../features/word_radar/presentation/screens/word_radar_screen.dart';
```

Inside the `/practice` `GoRoute`'s `routes: [...]` list (as a sibling of the `vocab`, `progress`, and `session` entries), add:

```dart
            GoRoute(
              path: 'radar',
              builder: (context, state) => const WordRadarScreen(),
            ),
```

- [ ] **Step 4: Add the hub card**

In `lib/features/practice/presentation/screens/practice_hub_screen.dart`, add a 5th `Card` after the "Tiến độ học tập" one, inside the `ListView`'s `children`:

```dart
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.radar_outlined),
              title: const Text('Quét từ vựng'),
              subtitle: const Text(
                'Dán văn bản bất kỳ để tìm từ đã học và gợi ý từ mới đáng học.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/practice/radar'),
            ),
          ),
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/practice/presentation/screens/practice_hub_screen_test.dart`
Expected: PASS — 2/2 tests.

Run: `flutter test`
Expected: PASS — full suite green.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/router/app_router.dart lib/features/practice/presentation/screens/practice_hub_screen.dart test/features/practice/presentation/screens/practice_hub_screen_test.dart
git commit -m "feat(word-radar): wire /practice/radar route and hub card"
```

---

## Final Verification

After Task 6, run the full checks one more time from the repo root:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Expected: `flutter analyze` reports only the pre-existing `RadioListTile` deprecation infos (12, unrelated to this work); `flutter test` passes with the pre-Task-1 baseline (300) plus this plan's new tests (2 + 6 + 4 + 1 + 3 + 5 + 2 = 23) = 323/323.
