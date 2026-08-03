# TOEIC Reading Part 5 + Part 6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two AI-generated TOEIC-style reading drills under a restructured `/reading` hub — **Part 5** (15 incomplete-sentence grammar/vocab questions) and **Part 6** (3 short business-document passages, 4 blanks each) — calibrated to Economy TOEIC Vol 2–5 difficulty, with answer explanations and reused new-word suggestions. Part 7 is explicitly out of scope for this plan.

**Architecture:** New files inside the existing `lib/features/reading/` module, following the exact same layering already used by `ReadingPassageSource`/`ListeningPassageSource`: a `*Source` class calls the shared `AiClientFactory`, a `Generate*UseCase` wraps it, a Riverpod `@riverpod` notifier holds session state (generate → answer → submit, mirroring `ListeningComprehensionNotifier`'s "answer all then submit" pattern — no per-turn playback needed since this is text, not audio), and three screens (home/session/result) per part. `/reading` becomes a hub screen (mirrors `ListeningHomeScreen`) with the existing bilingual reading content moved to `/reading/bilingual`.

**Tech Stack:** `AiClientFactory`/`GenerativeModelClient` (existing, provider-agnostic), Riverpod 2.x `@riverpod`, GoRouter, `uuid`, `flutter_test` + `mocktail`.

**Spec:** [2026-08-03-toeic-reading-part5-part6-design.md](../specs/2026-08-03-toeic-reading-part5-part6-design.md)

## Global Constraints

- Flutter SDK >=3.22.0, Dart >=3.4.0. Riverpod 2.x with `@riverpod` annotation — no `StateNotifier`, no `ChangeNotifier`. Navigation: GoRouter only — no `Navigator.push`.
- All domain entities: immutable, `const` constructors, no public setters.
- AI calls go through `AiClientFactory.buildClient(settings)` / `GenerativeModelClient` (`lib/core/services/ai_client_factory.dart`) — never construct a `GenerativeModel` directly. Use `parseAiJsonObject` (`lib/core/utils/ai_json_parser.dart`) to decode AI responses.
- **No Vocab Bank dependency, no minimum-word gate** — content is fully AI-generated, like Nghe hiểu. The only gate is `settings.aiEnabled`.
- **No SM-2 impact whatsoever** — neither part calls `ComputeSm2UseCase` or `updateVocabUseCaseProvider`. There is no specific vocab word to attribute a grammar-question result to.
- Difficulty is `EconomyVolume` (Vol 2–5), **not** the app's `CEFRLevel` — TOEIC prep difficulty doesn't map to CEFR. "Chủ đề" on both home screens means **AppContext** (same as Nghe hiểu), not Topic tag.
- Volume picker is **multi-select** (`showMultiSelectSheet<EconomyVolume>`), same widget already used for Topic filters. Empty selection = "all 4 volumes" (same convention as empty-Topic-selection = "no filter" elsewhere in the app). Sources resolve this — `volumes.isEmpty ? EconomyVolume.values.toSet() : volumes` — not the notifier or screen.
- Grading is answer-all-then-submit (not per-question feedback), matching `ListeningComprehensionNotifier`'s established pattern — `canSubmit` requires every answer non-null; `submit()` is a no-op otherwise.
- One AI call per generation (all 15 Part 5 questions, or all 3 Part 6 passages, in a single JSON response) — matches `ReadingPassageSource`/`ListeningPassageSource`'s existing multi-item-per-call convention.
- Both sources throw `FormatException` when the parsed result is empty (mirrors `ListeningPassageSource.generate()`'s `if (passage.turns.isEmpty || passage.questions.isEmpty) throw ...` guard) — never silently return an empty set.
- Part 6 blanks are numbered inline in `passageText` as `"(1)___"`..`"(4)___"` in reading order, **local to each passage** (not real-exam global numbering like 131–134) — purely cosmetic, no functional difference, and simpler to generate/parse.
- Part 6's per-passage question list always has exactly 4 items; `Part6SessionState.flatIndex(passageIndex, questionIndex) = passageIndex * 4 + questionIndex` is the fixed mapping from "which blank of which passage" to the flat `selectedAnswers` list index — safe to hardcode `4` since the domain model guarantees it.
- Every question/blank has an `explanation: String` field (Vietnamese) — new relative to `ListeningQuestion`/`Exercise`, which have no such field. Shown under each item in the result breakdown.
- Result screens reuse `VocabSuggestionsSection` + `getVocabSuggestionsForTextUseCaseProvider` **verbatim** (same call shape as `ComprehensionResultScreen`/`ReadingResultScreen`), fed the concatenation of the session's question/passage text, with `targetCefrLevel: null` (there is no CEFR level in these sessions, and the parameter is nullable).
- Result screens call `ref.read(statsServiceProvider).recordPracticeSession(<question count>)` for streak/stats, wrapped in try/catch best-effort (matches `ComprehensionResultScreen`/`ReadingResultScreen` exactly).
- After every edit to a file containing `@riverpod`/`@Riverpod` annotations, run `dart run build_runner build --delete-conflicting-outputs` before running tests.
- Run `flutter analyze` and `flutter test` at the end of every task; both must be clean before committing.
- `/reading` is reached only via the "Luyện tập" hub's card (`practice_hub_screen.dart`), never a bottom-nav destination — `AppShell` is not touched by this plan.

---

## File Structure

```text
lib/features/reading/
├── domain/
│   ├── entities/
│   │   ├── economy_volume.dart              CREATE
│   │   ├── part5_question.dart              CREATE — Part5Question, Part5Set
│   │   └── part6_passage.dart               CREATE — Part6Question, Part6Passage, Part6Set
│   └── use_cases/
│       ├── generate_part5_set_use_case.dart CREATE
│       └── generate_part6_set_use_case.dart CREATE
├── data/sources/
│   ├── part5_source.dart                    CREATE
│   └── part6_source.dart                    CREATE
└── presentation/
    ├── providers/
    │   ├── part5_practice_provider.dart     CREATE
    │   └── part6_practice_provider.dart     CREATE
    └── screens/
        ├── reading_hub_screen.dart          CREATE — replaces reading_home_screen.dart at "/reading"
        ├── part5_home_screen.dart           CREATE
        ├── part5_session_screen.dart        CREATE
        ├── part5_result_screen.dart         CREATE
        ├── part6_home_screen.dart           CREATE
        ├── part6_session_screen.dart        CREATE
        ├── part6_result_screen.dart         CREATE
        ├── reading_home_screen.dart         MODIFY — back button + internal nav target (now nested under /reading/bilingual)
        ├── reading_session_screen.dart      MODIFY — 2 route strings
        └── reading_result_screen.dart       MODIFY — 1 route string

lib/features/practice/presentation/screens/practice_hub_screen.dart  MODIFY — relabel "Đọc & gõ" card
lib/core/di/app_providers.dart                                       MODIFY — 4 new providers
lib/core/router/app_router.dart                                      MODIFY — restructure /reading routes
README.md                                                            MODIFY — document Part 5/6

test/features/reading/
├── domain/entities/economy_volume_test.dart                        CREATE
├── domain/entities/part5_question_test.dart                        CREATE
├── domain/entities/part6_passage_test.dart                         CREATE
├── domain/use_cases/generate_part5_set_use_case_test.dart          CREATE
├── domain/use_cases/generate_part6_set_use_case_test.dart          CREATE
├── data/sources/part5_source_test.dart                             CREATE
├── data/sources/part6_source_test.dart                             CREATE
├── presentation/providers/part5_practice_provider_test.dart        CREATE
├── presentation/providers/part6_practice_provider_test.dart        CREATE
└── presentation/screens/
    ├── reading_hub_screen_test.dart                                CREATE
    ├── part5_home_screen_test.dart                                 CREATE
    ├── part5_session_screen_test.dart                              CREATE
    ├── part5_result_screen_test.dart                               CREATE
    ├── part6_home_screen_test.dart                                 CREATE
    ├── part6_session_screen_test.dart                              CREATE
    ├── part6_result_screen_test.dart                               CREATE
    ├── reading_home_screen_test.dart                               MODIFY (only if back-button is asserted)
    ├── reading_session_screen_test.dart                            MODIFY — 1 route string
    └── reading_result_screen_test.dart                             MODIFY — 2 route strings

test/features/practice/presentation/screens/practice_hub_screen_test.dart  MODIFY — relabel assertion
```

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | EconomyVolume entity | `EconomyVolume` enum (Vol 2–5), `label`, `promptHint` |
| 02 | Part 5 domain entities | `Part5Question`, `Part5Set` |
| 03 | Part5Source | AI prompt → `Part5Set` (15 questions, 1 call) |
| 04 | GeneratePart5SetUseCase | thin wrapper over `Part5Source` |
| 05 | Part5PracticeNotifier | `Part5SessionState`, `Part5SessionResult`, generate/selectAnswer/submit/reset |
| 06 | Part5HomeScreen | Ngôn ngữ/Chủ đề/Độ khó(multi) filters, generate flow |
| 07 | Part5SessionScreen | 15-question list, submit gating |
| 08 | Part5ResultScreen | Score X/15, breakdown+explanation, suggestions, stats |
| 09 | Part 6 domain entities | `Part6Question`, `Part6Passage`, `Part6Set` |
| 10 | Part6Source | AI prompt → `Part6Set` (3 passages × 4 blanks, 1 call) |
| 11 | GeneratePart6SetUseCase | thin wrapper over `Part6Source` |
| 12 | Part6PracticeNotifier | `Part6SessionState` (flat answers + `flatIndex`), `Part6SessionResult` |
| 13 | Part6HomeScreen | same filter shape as Part 5 |
| 14 | Part6SessionScreen | 3 passages × 4-question groups, submit gating |
| 15 | Part6ResultScreen | Score X/12, grouped breakdown+explanation, suggestions, stats |
| 16 | Hub restructure + DI + Router + README | `ReadingHubScreen`, route nesting, DI wiring, Practice card relabel, README |

---

### Task 01: EconomyVolume Entity

**Files:**
- Create: `lib/features/reading/domain/entities/economy_volume.dart`
- Test: `test/features/reading/domain/entities/economy_volume_test.dart`

**Interfaces:**
- Produces: `enum EconomyVolume { vol2, vol3, vol4, vol5 }` with `.label` (`String`) and `.promptHint` (`String`) getters — consumed by every later task (sources, providers, screens).

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/domain/entities/economy_volume_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';

void main() {
  group('EconomyVolume', () {
    test('has exactly 4 values, Vol 2 through Vol 5', () {
      expect(EconomyVolume.values, [
        EconomyVolume.vol2,
        EconomyVolume.vol3,
        EconomyVolume.vol4,
        EconomyVolume.vol5,
      ]);
    });

    test('label describes each volume', () {
      expect(EconomyVolume.vol2.label, 'Vol 2 · 500–600+');
      expect(EconomyVolume.vol3.label, 'Vol 3 · 650–750+');
      expect(EconomyVolume.vol4.label, 'Vol 4 · 800–900+');
      expect(EconomyVolume.vol5.label, 'Vol 5 · 900+');
    });

    test('promptHint is non-empty and part-agnostic for every volume', () {
      for (final v in EconomyVolume.values) {
        expect(v.promptHint, isNotEmpty);
        expect(v.promptHint.toLowerCase(), isNot(contains('part 5')));
        expect(v.promptHint.toLowerCase(), isNot(contains('part 6')));
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/domain/entities/economy_volume_test.dart`
Expected: FAIL — `economy_volume.dart` does not exist (import error).

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/domain/entities/economy_volume.dart`:

```dart
enum EconomyVolume {
  vol2,
  vol3,
  vol4,
  vol5;

  String get label => switch (this) {
        EconomyVolume.vol2 => 'Vol 2 · 500–600+',
        EconomyVolume.vol3 => 'Vol 3 · 650–750+',
        EconomyVolume.vol4 => 'Vol 4 · 800–900+',
        EconomyVolume.vol5 => 'Vol 5 · 900+',
      };

  /// Fed into the AI prompt to calibrate question style/difficulty.
  /// Deliberately part-agnostic — shared across Part 5, Part 6, and (later) Part 7.
  String get promptHint => switch (this) {
        EconomyVolume.vol2 =>
          'easy-medium difficulty, standard trap depth, close to or slightly easier than the real exam',
        EconomyVolume.vol3 =>
          'medium-high difficulty, some advanced vocabulary, longer passages',
        EconomyVolume.vol4 =>
          'high difficulty, equal to or harder than the real exam, longer/more complex passages, unusual grammar/vocabulary traps',
        EconomyVolume.vol5 =>
          'very high difficulty, dense advanced vocabulary and the deepest grammar traps',
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/domain/entities/economy_volume_test.dart`
Expected: PASS — 3/3 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/domain/entities/economy_volume.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/domain/entities/economy_volume.dart test/features/reading/domain/entities/economy_volume_test.dart
git commit -m "feat(reading): add EconomyVolume difficulty enum (Vol 2-5)"
```

---

### Task 02: Part 5 Domain Entities

**Files:**
- Create: `lib/features/reading/domain/entities/part5_question.dart`
- Test: `test/features/reading/domain/entities/part5_question_test.dart`

**Interfaces:**
- Consumes: nothing new (imports `AppContext`, `Language` — existing; `EconomyVolume` — Task 01).
- Produces: `Part5Question({required String sentenceWithBlank, required List<String> options, required int correctIndex, required String explanation})`; `Part5Set({required String id, required List<Part5Question> questions, required Set<EconomyVolume> volumes, required AppContext context, required Language targetLanguage, required DateTime generatedAt})` — consumed by Tasks 03–08.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/domain/entities/part5_question_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';

void main() {
  group('Part5Question', () {
    test('holds sentence, 4 options, correct index, and explanation', () {
      const question = Part5Question(
        sentenceWithBlank: 'The report ___ by Friday.',
        options: ['finish', 'finished', 'will be finished', 'finishing'],
        correctIndex: 2,
        explanation: 'Cần thể bị động tương lai vì báo cáo được người khác hoàn thành.',
      );
      expect(question.sentenceWithBlank, contains('___'));
      expect(question.options.length, 4);
      expect(question.correctIndex, 2);
      expect(question.explanation, isNotEmpty);
    });
  });

  group('Part5Set', () {
    final set = Part5Set(
      id: 'test-id',
      questions: List.generate(
        15,
        (i) => Part5Question(
          sentenceWithBlank: 'Sentence $i ___.',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: i % 4,
          explanation: 'Explanation $i',
        ),
      ),
      volumes: const {EconomyVolume.vol3, EconomyVolume.vol4},
      context: AppContext.business,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 8, 3),
    );

    test('always has exactly 15 questions', () {
      expect(set.questions.length, 15);
    });

    test('holds volumes, context, targetLanguage', () {
      expect(set.volumes, {EconomyVolume.vol3, EconomyVolume.vol4});
      expect(set.context, AppContext.business);
      expect(set.targetLanguage, Language.english);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/domain/entities/part5_question_test.dart`
Expected: FAIL — `part5_question.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/domain/entities/part5_question.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import 'economy_volume.dart';

final class Part5Question {
  const Part5Question({
    required this.sentenceWithBlank,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String sentenceWithBlank; // contains exactly one '___'
  final List<String> options; // always 4 items
  final int correctIndex; // 0-3
  final String explanation; // Vietnamese, why the correct option is right
}

final class Part5Set {
  const Part5Set({
    required this.id,
    required this.questions,
    required this.volumes,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final List<Part5Question> questions; // always 15 items
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/domain/entities/part5_question_test.dart`
Expected: PASS — 3/3 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/domain/entities/part5_question.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/domain/entities/part5_question.dart test/features/reading/domain/entities/part5_question_test.dart
git commit -m "feat(reading): add Part5Question/Part5Set domain entities"
```

---

### Task 03: Part5Source

**Files:**
- Create: `lib/features/reading/data/sources/part5_source.dart`
- Test: `test/features/reading/data/sources/part5_source_test.dart`

**Interfaces:**
- Consumes: `Part5Question`/`Part5Set` (Task 02), `EconomyVolume` (Task 01), `AiClientFactory`/`GenerativeModelClient` (existing), `parseAiJsonObject` (existing).
- Produces: `Part5Source(UserSettingsState settings)`, `Part5Source.withModel(GenerativeModelClient client)`, `Future<Part5Set> generate({required AppContext context, required Language targetLanguage, required Set<EconomyVolume> volumes})` — consumed by Task 04.

- [ ] **Step 1: Write the failing tests**

Create `test/features/reading/data/sources/part5_source_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/reading/data/sources/part5_source_test.dart`
Expected: FAIL — `part5_source.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/data/sources/part5_source.dart`:

```dart
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part5_question.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class Part5Source {
  Part5Source(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  Part5Source.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();
  static const _questionCount = 15;

  Future<Part5Set> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    final effectiveVolumes = volumes.isEmpty ? EconomyVolume.values.toSet() : volumes;
    final prompt = _buildPrompt(
      context: context,
      targetLanguage: targetLanguage,
      volumes: effectiveVolumes,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{"questions":[]}';
    final json = parseAiJsonObject(text);
    final set = _parse(json, effectiveVolumes, context, targetLanguage);
    if (set.questions.isEmpty) {
      throw const FormatException(
        'AI response produced an empty Part 5 question set.',
      );
    }
    return set;
  }

  String _buildPrompt({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) {
    final volumeHints = volumes.map((v) => '${v.label}: ${v.promptHint}').join('; ');
    return 'You are creating a TOEIC Part 5 (Incomplete Sentences) practice set for a '
        'Vietnamese speaker learning ${targetLanguage.label}, in a ${context.label} '
        'register/setting, calibrated to the Economy TOEIC difficulty volumes below '
        '(mix questions across them roughly evenly and randomly): $volumeHints. '
        'Write exactly $_questionCount independent sentences, each with exactly one blank '
        'marked "___", testing grammar (word form, verb tense/agreement, prepositions, '
        'conjunctions) or vocabulary-in-context, with exactly 4 answer options in '
        '${targetLanguage.label} and a brief explanation (in Vietnamese) of why the correct '
        'option is right and, briefly, why the others are wrong. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"questions": [{"sentenceWithBlank": "...", "options": ["...", "...", "...", "..."], '
        '"correctIndex": 0, "explanation": "..."}]}';
  }

  Part5Set _parse(
    Map<String, dynamic> json,
    Set<EconomyVolume> volumes,
    AppContext context,
    Language targetLanguage,
  ) {
    final questions = (json['questions'] as List? ?? []).map((q) {
      final qm = q as Map<String, dynamic>;
      return Part5Question(
        sentenceWithBlank: qm['sentenceWithBlank'] as String? ?? '',
        options: List<String>.from(qm['options'] as List? ?? []),
        correctIndex: qm['correctIndex'] as int? ?? 0,
        explanation: qm['explanation'] as String? ?? '',
      );
    }).toList();

    return Part5Set(
      id: _uuid.v4(),
      questions: questions,
      volumes: volumes,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reading/data/sources/part5_source_test.dart`
Expected: PASS — 4/4 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/data/sources/part5_source.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/data/sources/part5_source.dart test/features/reading/data/sources/part5_source_test.dart
git commit -m "feat(reading): add Part5Source (AI generation for TOEIC Part 5)"
```

---

### Task 04: GeneratePart5SetUseCase

**Files:**
- Create: `lib/features/reading/domain/use_cases/generate_part5_set_use_case.dart`
- Test: `test/features/reading/domain/use_cases/generate_part5_set_use_case_test.dart`

**Interfaces:**
- Consumes: `Part5Source` (Task 03).
- Produces: `GeneratePart5SetUseCase(Part5Source source)`, `Future<Part5Set> execute({required AppContext context, required Language targetLanguage, required Set<EconomyVolume> volumes})` — consumed by Task 05 and Task 16 (DI).

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/domain/use_cases/generate_part5_set_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part5_source.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part5_set_use_case.dart';

class MockPart5Source extends Mock implements Part5Source {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  late MockPart5Source mockSource;
  late GeneratePart5SetUseCase useCase;

  setUp(() {
    mockSource = MockPart5Source();
    useCase = GeneratePart5SetUseCase(mockSource);
  });

  final fakeSet = Part5Set(
    id: 'fake-id',
    questions: const [],
    volumes: const {EconomyVolume.vol3},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the set', () async {
    when(
      () => mockSource.generate(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fakeSet);

    final result = await useCase.execute(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );
    expect(result, same(fakeSet));
    verify(
      () => mockSource.generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol3},
      ),
    ).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/domain/use_cases/generate_part5_set_use_case_test.dart`
Expected: FAIL — `generate_part5_set_use_case.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/domain/use_cases/generate_part5_set_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../data/sources/part5_source.dart';
import '../entities/economy_volume.dart';
import '../entities/part5_question.dart';

class GeneratePart5SetUseCase {
  const GeneratePart5SetUseCase(this._source);
  final Part5Source _source;

  Future<Part5Set> execute({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) =>
      _source.generate(
        context: context,
        targetLanguage: targetLanguage,
        volumes: volumes,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/domain/use_cases/generate_part5_set_use_case_test.dart`
Expected: PASS — 1/1 test.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/domain/use_cases/generate_part5_set_use_case.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/domain/use_cases/generate_part5_set_use_case.dart test/features/reading/domain/use_cases/generate_part5_set_use_case_test.dart
git commit -m "feat(reading): add GeneratePart5SetUseCase"
```

---

### Task 05: Part5PracticeNotifier

**Files:**
- Create: `lib/features/reading/presentation/providers/part5_practice_provider.dart`
- Create: `lib/features/reading/presentation/providers/part5_practice_provider.g.dart` (generated)
- Test: `test/features/reading/presentation/providers/part5_practice_provider_test.dart`
- Modify: `lib/core/di/app_providers.dart` (add `Part5Source`/`GeneratePart5SetUseCase` providers so the notifier compiles)

**Interfaces:**
- Consumes: `GeneratePart5SetUseCase` (Task 04, now DI-registered).
- Produces: `Part5SessionResult({required Part5Set set, required List<int?> selectedAnswers})` with `correctCount` getter; `Part5SessionState({required Part5Set set, required List<int?> selectedAnswers, required bool isSubmitted})` with `canSubmit` getter + `copyWith`; `part5PracticeNotifierProvider`; `Part5PracticeNotifier.generate({required AppContext context, required Language targetLanguage, required Set<EconomyVolume> volumes})`, `.selectAnswer(int questionIndex, int optionIndex)`, `.submit()`, `.reset()` — consumed by Tasks 06–08.

- [ ] **Step 1: Register Part5Source/GeneratePart5SetUseCase DI (needed for the test container)**

In `lib/core/di/app_providers.dart`, add this import block after the existing `// --- Reading DI (Plan 7) ---` imports:

```dart
import '../../features/reading/data/sources/part5_source.dart';
import '../../features/reading/domain/use_cases/generate_part5_set_use_case.dart';
```

Add these providers at the end of the file:

```dart

@riverpod
Part5Source part5Source(Part5SourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return Part5Source(settings);
}

@riverpod
GeneratePart5SetUseCase generatePart5SetUseCase(GeneratePart5SetUseCaseRef ref) =>
    GeneratePart5SetUseCase(ref.watch(part5SourceProvider));
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2: Write the failing test**

Create `test/features/reading/presentation/providers/part5_practice_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part5_set_use_case.dart';
import 'package:lexi_core/features/reading/presentation/providers/part5_practice_provider.dart';

class MockGeneratePart5SetUseCase extends Mock implements GeneratePart5SetUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  final fixedSet = Part5Set(
    id: 'p1',
    questions: List.generate(
      3,
      (i) => Part5Question(
        sentenceWithBlank: 'Sentence $i ___.',
        options: const ['a', 'b', 'c', 'd'],
        correctIndex: i % 4,
        explanation: 'Explanation $i',
      ),
    ),
    volumes: const {EconomyVolume.vol3},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  late MockGeneratePart5SetUseCase mockUseCase;
  late ProviderContainer container;

  setUp(() {
    mockUseCase = MockGeneratePart5SetUseCase();
    when(
      () => mockUseCase.execute(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fixedSet);

    container = ProviderContainer(
      overrides: [generatePart5SetUseCaseProvider.overrideWithValue(mockUseCase)],
    );
    addTearDown(container.dispose);
  });

  Future<void> generateFixed() => container.read(part5PracticeNotifierProvider.notifier).generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol3},
      );

  test('generate() populates state with all answers unselected', () async {
    await generateFixed();
    final state = container.read(part5PracticeNotifierProvider).valueOrNull!;
    expect(state.set, same(fixedSet));
    expect(state.selectedAnswers, [null, null, null]);
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test('selectAnswer() records an answer without marking submitted', () async {
    await generateFixed();
    final notifier = container.read(part5PracticeNotifierProvider.notifier);
    notifier.selectAnswer(0, 2);
    final state = container.read(part5PracticeNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers, [2, null, null]);
    expect(state.isSubmitted, false);
  });

  test('canSubmit is true only once every answer is selected', () async {
    await generateFixed();
    final notifier = container.read(part5PracticeNotifierProvider.notifier);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 1);
    expect(container.read(part5PracticeNotifierProvider).valueOrNull!.canSubmit, false);
    notifier.selectAnswer(2, 2);
    expect(container.read(part5PracticeNotifierProvider).valueOrNull!.canSubmit, true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier = container.read(part5PracticeNotifierProvider.notifier);
    notifier.submit();
    expect(container.read(part5PracticeNotifierProvider).valueOrNull!.isSubmitted, false);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 0);
    notifier.selectAnswer(2, 0);
    notifier.submit();
    expect(container.read(part5PracticeNotifierProvider).valueOrNull!.isSubmitted, true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(part5PracticeNotifierProvider.notifier).reset();
    expect(container.read(part5PracticeNotifierProvider).valueOrNull, isNull);
  });

  test('Part5SessionResult.correctCount counts matching answers', () {
    final result = Part5SessionResult(
      set: fixedSet,
      selectedAnswers: const [0, 1, 3], // question 0 & 1's correctIndex are 0 & 1; question 2's is 2
    );
    expect(result.correctCount, 2);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/providers/part5_practice_provider_test.dart`
Expected: FAIL — `part5_practice_provider.dart` does not exist.

- [ ] **Step 4: Write the implementation**

Create `lib/features/reading/presentation/providers/part5_practice_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part5_question.dart';

part 'part5_practice_provider.g.dart';

final class Part5SessionResult {
  const Part5SessionResult({required this.set, required this.selectedAnswers});

  final Part5Set set;
  final List<int?> selectedAnswers; // length == set.questions.length

  int get correctCount {
    int count = 0;
    for (int i = 0; i < set.questions.length; i++) {
      if (selectedAnswers[i] == set.questions[i].correctIndex) count++;
    }
    return count;
  }
}

final class Part5SessionState {
  const Part5SessionState({
    required this.set,
    required this.selectedAnswers,
    required this.isSubmitted,
  });

  final Part5Set set;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  bool get canSubmit => selectedAnswers.every((a) => a != null);

  Part5SessionState copyWith({List<int?>? selectedAnswers, bool? isSubmitted}) =>
      Part5SessionState(
        set: set,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

@riverpod
class Part5PracticeNotifier extends _$Part5PracticeNotifier {
  @override
  AsyncValue<Part5SessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final set = await ref.read(generatePart5SetUseCaseProvider).execute(
            context: context,
            targetLanguage: targetLanguage,
            volumes: volumes,
          );
      return Part5SessionState(
        set: set,
        selectedAnswers: List<int?>.filled(set.questions.length, null),
        isSubmitted: false,
      );
    });
  }

  void selectAnswer(int questionIndex, int optionIndex) {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final updated = List<int?>.from(current.selectedAnswers);
    updated[questionIndex] = optionIndex;
    state = AsyncData(current.copyWith(selectedAnswers: updated));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted || !current.canSubmit) return;
    state = AsyncData(current.copyWith(isSubmitted: true));
  }

  void reset() => state = const AsyncData(null);
}
```

- [ ] **Step 5: Generate Riverpod code and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/reading/presentation/providers/part5_practice_provider_test.dart`
Expected: PASS — 6/6 tests.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/reading/ lib/core/di/app_providers.dart`
Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/reading/presentation/providers/part5_practice_provider.dart \
        lib/features/reading/presentation/providers/part5_practice_provider.g.dart \
        lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart \
        test/features/reading/presentation/providers/part5_practice_provider_test.dart
git commit -m "feat(reading): add Part5PracticeNotifier + DI wiring for Part 5"
```

---

### Task 06: Part5HomeScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part5_home_screen.dart`
- Test: `test/features/reading/presentation/screens/part5_home_screen_test.dart`

**Interfaces:**
- Consumes: `part5PracticeNotifierProvider` (Task 05), `userSettingsNotifierProvider` (existing), `FilterTile`/`showSingleSelectSheet`/`showMultiSelectSheet` (existing, `lib/core/widgets/`).
- Produces: `Part5HomeScreen` widget — navigates to `/reading/part5/session` on successful generate (route added in Task 16; the widget test below registers its own stub route so it doesn't depend on Task 16).

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part5_home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part5_home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

Widget _buildHome({required UserSettingsState settings}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part5HomeScreen()),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows AI disabled message when aiEnabled is false', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: false),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tính năng này yêu cầu AI'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI is enabled (no vocab gate)', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });

  testWidgets('shows language, context and difficulty pickers', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Độ khó'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget); // no volumes selected yet
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/part5_home_screen_test.dart`
Expected: FAIL — `part5_home_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part5_home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/economy_volume.dart';
import '../providers/part5_practice_provider.dart';

class Part5HomeScreen extends ConsumerStatefulWidget {
  const Part5HomeScreen({super.key});

  @override
  ConsumerState<Part5HomeScreen> createState() => _Part5HomeScreenState();
}

class _Part5HomeScreenState extends ConsumerState<Part5HomeScreen> {
  late Language _language;
  late AppContext _context;
  final Set<EconomyVolume> _volumes = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsNotifierProvider);
    _language = settings.targetLanguage;
    _context = settings.activeContext;
  }

  Future<void> _pickLanguage() async {
    final result = await showSingleSelectSheet<Language>(
      context: context,
      title: 'Ngôn ngữ',
      options: Language.values.map((l) => SelectOption(value: l, label: l.label)).toList(),
      selected: _language,
    );
    if (result != null) setState(() => _language = result.value);
  }

  Future<void> _pickContext() async {
    final result = await showSingleSelectSheet<AppContext>(
      context: context,
      title: 'Chủ đề',
      options: AppContext.values
          .map((c) => SelectOption(value: c, label: c.label, emoji: c.emoji))
          .toList(),
      selected: _context,
    );
    if (result != null) setState(() => _context = result.value);
  }

  Future<void> _pickVolumes() async {
    final result = await showMultiSelectSheet<EconomyVolume>(
      context: context,
      title: 'Độ khó',
      options: EconomyVolume.values.map((v) => SelectOption(value: v, label: v.label)).toList(),
      initialSelected: _volumes,
    );
    if (result != null) {
      setState(() {
        _volumes
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final sessionAsync = ref.watch(part5PracticeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Part 5 — Điền câu'),
        leading: BackButton(onPressed: () => context.go('/reading')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'AI tạo 15 câu điền từ/ngữ pháp kiểu TOEIC Part 5. Chọn đáp án đúng cho mỗi câu.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            FilterTile(
              icon: Icons.language_outlined,
              label: 'Ngôn ngữ',
              value: _language.label,
              onTap: _pickLanguage,
            ),
            FilterTile(
              icon: Icons.sell_outlined,
              label: 'Chủ đề',
              value: '${_context.emoji} ${_context.label}',
              onTap: _pickContext,
            ),
            FilterTile(
              icon: Icons.speed_outlined,
              label: 'Độ khó',
              value: _volumes.isEmpty ? 'Tất cả' : '${_volumes.length} đã chọn',
              onTap: _pickVolumes,
            ),
            const SizedBox(height: 16),
            if (!settings.aiEnabled)
              _ErrorCard(
                message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else
              sessionAsync.when(
                data: (_) => FilledButton.icon(
                  onPressed: () => _generate(context, ref),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Tạo bài luyện'),
                ),
                loading: () => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang tạo bài...'),
                  ],
                ),
                error: (e, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lỗi tạo bài: $e', style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _generate(context, ref),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    await ref.read(part5PracticeNotifierProvider.notifier).generate(
          context: _context,
          targetLanguage: _language,
          volumes: _volumes,
        );
    if (context.mounted) {
      final session = ref.read(part5PracticeNotifierProvider).valueOrNull;
      if (session != null) context.go('/reading/part5/session');
    }
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/part5_home_screen_test.dart`
Expected: PASS — 3/3 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/presentation/screens/part5_home_screen.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part5_home_screen.dart test/features/reading/presentation/screens/part5_home_screen_test.dart
git commit -m "feat(reading): add Part5HomeScreen"
```

---

### Task 07: Part5SessionScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part5_session_screen.dart`
- Test: `test/features/reading/presentation/screens/part5_session_screen_test.dart`

**Interfaces:**
- Consumes: `part5PracticeNotifierProvider`, `Part5SessionState`, `Part5SessionResult` (Task 05).
- Produces: `Part5SessionScreen` widget — navigates to `/reading/part5/session/result` with a `Part5SessionResult` as `extra` once `isSubmitted` flips true; navigates back to `/reading/part5` if state is null (e.g. hot-reload/back-navigation edge case).

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part5_session_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';
import 'package:lexi_core/features/reading/presentation/providers/part5_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part5_session_screen.dart';

final _testSet = Part5Set(
  id: 'test',
  questions: List.generate(
    3,
    (i) => Part5Question(
      sentenceWithBlank: 'Sentence $i ___.',
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: i % 4,
      explanation: 'Explanation $i',
    ),
  ),
  volumes: const {EconomyVolume.vol3},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _testSession = Part5SessionState(
  set: _testSet,
  selectedAnswers: const [null, null, null],
  isSubmitted: false,
);

class _FakePart5Notifier extends Part5PracticeNotifier {
  _FakePart5Notifier(this._session);
  final Part5SessionState _session;

  @override
  AsyncValue<Part5SessionState?> build() => AsyncData(_session);
}

Widget _buildSession({Part5SessionState? session}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part5SessionScreen()),
      GoRoute(
        path: '/reading/part5/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
      ),
      GoRoute(
        path: '/reading/part5',
        builder: (ctx, state) => const Scaffold(body: Text('Part5 home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      part5PracticeNotifierProvider
          .overrideWith(() => _FakePart5Notifier(session ?? _testSession)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows all 3 question sentences', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.textContaining('Sentence 0 ___.'), findsOneWidget);
    expect(find.textContaining('Sentence 1 ___.'), findsOneWidget);
    expect(find.textContaining('Sentence 2 ___.'), findsOneWidget);
  });

  testWidgets('Nộp bài is disabled until all answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part5SessionState(set: _testSet, selectedAnswers: const [0, 1, 2], isSubmitted: false),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('selecting an option and submitting navigates to the result screen', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part5SessionState(set: _testSet, selectedAnswers: const [0, 1, 2], isSubmitted: false),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();
    expect(find.text('Result screen'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/part5_session_screen_test.dart`
Expected: FAIL — `part5_session_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part5_session_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/part5_question.dart';
import '../providers/part5_practice_provider.dart';

class Part5SessionScreen extends ConsumerWidget {
  const Part5SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Part5SessionState?>>(part5PracticeNotifierProvider, (prev, next) {
      final session = next.valueOrNull;
      if (session == null) return;
      if (session.isSubmitted) {
        final result = Part5SessionResult(set: session.set, selectedAnswers: session.selectedAnswers);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/reading/part5/session/result', extra: result);
          }
        });
      }
    });

    final sessionAsync = ref.watch(part5PracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/reading/part5');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (session.isSubmitted) return const Scaffold(body: SizedBox.shrink());
        return _SessionScaffold(session: session);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({required this.session});
  final Part5SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(part5PracticeNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Part 5 — Điền câu'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < session.set.questions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _QuestionCard(
                        index: i,
                        question: session.set.questions[i],
                        selected: session.selectedAnswers[i],
                        onSelected: (optionIndex) => notifier.selectAnswer(i, optionIndex),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: session.canSubmit ? notifier.submit : null,
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int index;
  final Part5Question question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${index + 1}. ${question.sentenceWithBlank}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...question.options.asMap().entries.map(
                  (entry) => RadioListTile<int>(
                    value: entry.key,
                    groupValue: selected,
                    title: Text(entry.value),
                    dense: true,
                    onChanged: (v) {
                      if (v != null) onSelected(v);
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/part5_session_screen_test.dart`
Expected: PASS — 4/4 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/presentation/screens/part5_session_screen.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part5_session_screen.dart test/features/reading/presentation/screens/part5_session_screen_test.dart
git commit -m "feat(reading): add Part5SessionScreen"
```

---

### Task 08: Part5ResultScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part5_result_screen.dart`
- Test: `test/features/reading/presentation/screens/part5_result_screen_test.dart`

**Interfaces:**
- Consumes: `Part5SessionResult` (Task 05), `statsServiceProvider` (existing, `lib/core/di/app_providers.dart`), `getVocabSuggestionsForTextUseCaseProvider` (existing), `VocabSuggestionsSection` (existing, `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart`).
- Produces: `Part5ResultScreen({required Part5SessionResult result})` — "Bài khác" resets and goes to `/reading/part5`; "Về trang chính" resets and goes to `/`.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part5_result_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';
import 'package:lexi_core/features/reading/presentation/providers/part5_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part5_result_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';

class MockStatsService extends Mock implements StatsService {}

class MockGetVocabSuggestionsForTextUseCase extends Mock
    implements GetVocabSuggestionsForTextUseCase {}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

final _testSet = Part5Set(
  id: 'p1',
  questions: const [
    Part5Question(sentenceWithBlank: 'A ___.', options: ['a', 'b', 'c', 'd'], correctIndex: 0, explanation: 'Vì A đúng.'),
    Part5Question(sentenceWithBlank: 'B ___.', options: ['a', 'b', 'c', 'd'], correctIndex: 1, explanation: 'Vì B đúng.'),
    Part5Question(sentenceWithBlank: 'C ___.', options: ['a', 'b', 'c', 'd'], correctIndex: 2, explanation: 'Vì C đúng.'),
  ],
  volumes: const {EconomyVolume.vol3},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

// selectedAnswers: [0 (correct), 0 (wrong, correct is 1), 2 (correct)] -> 2/3
final _testResult = Part5SessionResult(set: _testSet, selectedAnswers: const [0, 0, 2]);

Future<Widget> _buildResult({List<Override> extraOverrides = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => Part5ResultScreen(result: _testResult)),
      GoRoute(path: '/reading/part5', builder: (ctx, state) => const Scaffold(body: Text('Part5 home'))),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults.copyWith(aiEnabled: true)),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  testWidgets('shows the score as correctCount/total', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('shows all question sentences, explanations, and correct/incorrect icons',
      (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('A ___.'), findsOneWidget);
    expect(find.textContaining('B ___.'), findsOneWidget);
    expect(find.textContaining('C ___.'), findsOneWidget);
    expect(find.textContaining('Vì A đúng.'), findsOneWidget);
    expect(find.textContaining('Vì B đúng.'), findsOneWidget);
    expect(find.textContaining('Vì C đúng.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.cancel), findsNWidgets(1));
  });

  testWidgets('shows Bài khác and Về trang chính buttons', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Bài khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets('records a practice session with the question count', (tester) async {
    final mockStats = MockStatsService();
    when(() => mockStats.recordPracticeSession(any())).thenAnswer((_) async {});

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [statsServiceProvider.overrideWithValue(mockStats)],
    ));
    await tester.pumpAndSettle();

    verify(() => mockStats.recordPracticeSession(3)).called(1);
  });

  testWidgets('loads new-word suggestions for the concatenated question text with a null CEFR level',
      (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenAnswer((_) async => const WordRadarAiResult(
          translation: '',
          suggestions: [
            WordPhraseResult(
              headword: 'ubiquitous',
              inputType: InputType.word,
              ipa: '/juːˈbɪkwɪtəs/',
              meaning: 'có mặt khắp nơi',
              examples: [],
              suggestedTopics: [],
            ),
          ],
        ));

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions)],
    ));
    await tester.pumpAndSettle();

    verify(() => mockSuggestions.execute(
          text: 'A ___. B ___. C ___.',
          targetLanguage: Language.english,
          targetCefrLevel: null,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/part5_result_screen_test.dart`
Expected: FAIL — `part5_result_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part5_result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
import '../../domain/entities/part5_question.dart';
import '../providers/part5_practice_provider.dart';

class Part5ResultScreen extends ConsumerStatefulWidget {
  const Part5ResultScreen({super.key, required this.result});
  final Part5SessionResult result;

  @override
  ConsumerState<Part5ResultScreen> createState() => _Part5ResultScreenState();
}

class _Part5ResultScreenState extends ConsumerState<Part5ResultScreen> {
  Part5SessionResult get result => widget.result;

  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(result.set.questions.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _questionsText => result.set.questions.map((q) => q.sentenceWithBlank).join(' ');

  Future<void> _loadSuggestions() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final aiResult = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: _questionsText,
            targetLanguage: result.set.targetLanguage,
            targetCefrLevel: null,
          ),
    );
    if (mounted) setState(() => _suggestions = aiResult);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = result.set.questions.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '${result.correctCount}/$total',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: result.correctCount == total
                      ? Colors.green.shade700
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...result.set.questions.asMap().entries.map((entry) {
                      final i = entry.key;
                      return _QuestionBreakdown(
                        index: i,
                        question: entry.value,
                        selected: result.selectedAnswers[i],
                      );
                    }),
                    _buildSuggestionsSection(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => _regenerate(context, ref), child: const Text('Bài khác')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _goHome(context, ref), child: const Text('Về trang chính')),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(onPressed: _loadSuggestions, child: const Text('Thử lại')),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(part5PracticeNotifierProvider.notifier).reset();
    context.go('/reading/part5');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(part5PracticeNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({required this.index, required this.question, required this.selected});

  final int index;
  final Part5Question question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = selected == question.correctIndex;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${index + 1}. ${question.sentenceWithBlank}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...question.options.asMap().entries.map((entry) {
              final i = entry.key;
              final isCorrectOption = i == question.correctIndex;
              final isSelectedOption = i == selected;
              Color? color;
              if (isCorrectOption) {
                color = Colors.green;
              } else if (isSelectedOption) {
                color = theme.colorScheme.error;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  entry.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: (isCorrectOption || isSelectedOption) ? FontWeight.bold : null,
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            Text(
              'Giải thích: ${question.explanation}',
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/part5_result_screen_test.dart`
Expected: PASS — 5/5 tests.

- [ ] **Step 5: Analyze and run the full Part 5 test slice**

Run: `flutter analyze lib/features/reading/`
Run: `flutter test test/features/reading/`
Expected: no issues; all Part 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part5_result_screen.dart test/features/reading/presentation/screens/part5_result_screen_test.dart
git commit -m "feat(reading): add Part5ResultScreen (score, explanations, vocab suggestions)"
```

---

### Task 09: Part 6 Domain Entities

**Files:**
- Create: `lib/features/reading/domain/entities/part6_passage.dart`
- Test: `test/features/reading/domain/entities/part6_passage_test.dart`

**Interfaces:**
- Produces: `Part6Question({required List<String> options, required int correctIndex, required String explanation})`; `Part6Passage({required String passageText, required List<Part6Question> questions})`; `Part6Set({required String id, required List<Part6Passage> passages, required Set<EconomyVolume> volumes, required AppContext context, required Language targetLanguage, required DateTime generatedAt})` — consumed by Tasks 10–15.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/domain/entities/part6_passage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';

Part6Passage _passage(int i) => Part6Passage(
      passageText: 'Passage $i text with (1)___ (2)___ (3)___ (4)___ blanks.',
      questions: List.generate(
        4,
        (q) => Part6Question(
          options: ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Explanation $i-$q',
        ),
      ),
    );

void main() {
  group('Part6Question', () {
    test('holds 4 options, correct index, and explanation', () {
      const question = Part6Question(
        options: ['increase', 'increased', 'increasing', 'will increase'],
        correctIndex: 3,
        explanation: 'Cần thì tương lai vì mệnh đề chỉ kế hoạch sắp tới.',
      );
      expect(question.options.length, 4);
      expect(question.correctIndex, 3);
      expect(question.explanation, isNotEmpty);
    });
  });

  group('Part6Passage', () {
    test('always has exactly 4 questions', () {
      expect(_passage(0).questions.length, 4);
    });

    test('passageText contains all 4 numbered blank markers', () {
      final text = _passage(0).passageText;
      expect(text, contains('(1)___'));
      expect(text, contains('(2)___'));
      expect(text, contains('(3)___'));
      expect(text, contains('(4)___'));
    });
  });

  group('Part6Set', () {
    final set = Part6Set(
      id: 'test-id',
      passages: List.generate(3, _passage),
      volumes: const {EconomyVolume.vol4},
      context: AppContext.business,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 8, 3),
    );

    test('always has exactly 3 passages', () {
      expect(set.passages.length, 3);
    });

    test('holds volumes, context, targetLanguage', () {
      expect(set.volumes, {EconomyVolume.vol4});
      expect(set.context, AppContext.business);
      expect(set.targetLanguage, Language.english);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/domain/entities/part6_passage_test.dart`
Expected: FAIL — `part6_passage.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/domain/entities/part6_passage.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import 'economy_volume.dart';

final class Part6Question {
  const Part6Question({
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final List<String> options; // always 4 — words/phrases OR full sentences
  final int correctIndex; // 0-3
  final String explanation; // Vietnamese, why the correct option is right
}

final class Part6Passage {
  const Part6Passage({required this.passageText, required this.questions});

  final String passageText; // blanks inline, e.g. "... the office (1)___ Monday ..."
  final List<Part6Question> questions; // always 4, ordered to match blank numbering
}

final class Part6Set {
  const Part6Set({
    required this.id,
    required this.passages,
    required this.volumes,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final List<Part6Passage> passages; // always 3
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/domain/entities/part6_passage_test.dart`
Expected: PASS — 5/5 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/domain/entities/part6_passage.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/domain/entities/part6_passage.dart test/features/reading/domain/entities/part6_passage_test.dart
git commit -m "feat(reading): add Part6Question/Part6Passage/Part6Set domain entities"
```

---

### Task 10: Part6Source

**Files:**
- Create: `lib/features/reading/data/sources/part6_source.dart`
- Test: `test/features/reading/data/sources/part6_source_test.dart`

**Interfaces:**
- Consumes: `Part6Question`/`Part6Passage`/`Part6Set` (Task 09), `EconomyVolume` (Task 01), `AiClientFactory`/`GenerativeModelClient`, `parseAiJsonObject` (existing).
- Produces: `Part6Source(UserSettingsState settings)`, `Part6Source.withModel(GenerativeModelClient client)`, `Future<Part6Set> generate({required AppContext context, required Language targetLanguage, required Set<EconomyVolume> volumes})` — consumed by Task 11.

- [ ] **Step 1: Write the failing tests**

Create `test/features/reading/data/sources/part6_source_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/reading/data/sources/part6_source_test.dart`
Expected: FAIL — `part6_source.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/data/sources/part6_source.dart`:

```dart
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part6_passage.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class Part6Source {
  Part6Source(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  Part6Source.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();
  static const _passageCount = 3;
  static const _blanksPerPassage = 4;

  Future<Part6Set> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    final effectiveVolumes = volumes.isEmpty ? EconomyVolume.values.toSet() : volumes;
    final prompt = _buildPrompt(
      context: context,
      targetLanguage: targetLanguage,
      volumes: effectiveVolumes,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{"passages":[]}';
    final json = parseAiJsonObject(text);
    final set = _parse(json, effectiveVolumes, context, targetLanguage);
    if (set.passages.isEmpty) {
      throw const FormatException(
        'AI response produced an empty Part 6 passage set.',
      );
    }
    return set;
  }

  String _buildPrompt({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) {
    final volumeHints = volumes.map((v) => '${v.label}: ${v.promptHint}').join('; ');
    return 'You are creating a TOEIC Part 6 (Text Completion) practice set for a Vietnamese '
        'speaker learning ${targetLanguage.label}, in a ${context.label} register/setting, '
        'calibrated to the Economy TOEIC difficulty volumes below (mix passages across them '
        'roughly evenly and randomly): $volumeHints. '
        'Write exactly $_passageCount short realistic business documents (choose from: email, '
        'memo, notice, advertisement, article), each with exactly $_blanksPerPassage numbered '
        'blanks marked inline as "(1)___", "(2)___", "(3)___", "(4)___" in reading order. '
        'For each passage, at least one of its 4 blanks must be a "select the sentence that '
        'best fits" item, where all 4 options are full candidate sentences instead of single '
        'words/phrases — the other blanks use word/phrase options (word form, verb tense, '
        'preposition, conjunction, transition word). Every blank has exactly 4 options and a '
        'brief explanation (in Vietnamese) of why the correct option is right. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"passages": [{"passageText": "... (1)___ ... (2)___ ... (3)___ ... (4)___ ...", '
        '"questions": [{"options": ["...", "...", "...", "..."], "correctIndex": 0, '
        '"explanation": "..."}]}]}';
  }

  Part6Set _parse(
    Map<String, dynamic> json,
    Set<EconomyVolume> volumes,
    AppContext context,
    Language targetLanguage,
  ) {
    final passages = (json['passages'] as List? ?? []).map((p) {
      final pm = p as Map<String, dynamic>;
      final questions = (pm['questions'] as List? ?? []).map((q) {
        final qm = q as Map<String, dynamic>;
        return Part6Question(
          options: List<String>.from(qm['options'] as List? ?? []),
          correctIndex: qm['correctIndex'] as int? ?? 0,
          explanation: qm['explanation'] as String? ?? '',
        );
      }).toList();
      return Part6Passage(
        passageText: pm['passageText'] as String? ?? '',
        questions: questions,
      );
    }).toList();

    return Part6Set(
      id: _uuid.v4(),
      passages: passages,
      volumes: volumes,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reading/data/sources/part6_source_test.dart`
Expected: PASS — 4/4 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/data/sources/part6_source.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/data/sources/part6_source.dart test/features/reading/data/sources/part6_source_test.dart
git commit -m "feat(reading): add Part6Source (AI generation for TOEIC Part 6)"
```

---

### Task 11: GeneratePart6SetUseCase

**Files:**
- Create: `lib/features/reading/domain/use_cases/generate_part6_set_use_case.dart`
- Test: `test/features/reading/domain/use_cases/generate_part6_set_use_case_test.dart`

**Interfaces:**
- Consumes: `Part6Source` (Task 10).
- Produces: `GeneratePart6SetUseCase(Part6Source source)`, `Future<Part6Set> execute({required AppContext context, required Language targetLanguage, required Set<EconomyVolume> volumes})` — consumed by Task 12 and Task 16 (DI).

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/domain/use_cases/generate_part6_set_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part6_source.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part6_set_use_case.dart';

class MockPart6Source extends Mock implements Part6Source {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  late MockPart6Source mockSource;
  late GeneratePart6SetUseCase useCase;

  setUp(() {
    mockSource = MockPart6Source();
    useCase = GeneratePart6SetUseCase(mockSource);
  });

  final fakeSet = Part6Set(
    id: 'fake-id',
    passages: const [],
    volumes: const {EconomyVolume.vol4},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the set', () async {
    when(
      () => mockSource.generate(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fakeSet);

    final result = await useCase.execute(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol4},
    );
    expect(result, same(fakeSet));
    verify(
      () => mockSource.generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol4},
      ),
    ).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/domain/use_cases/generate_part6_set_use_case_test.dart`
Expected: FAIL — `generate_part6_set_use_case.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/domain/use_cases/generate_part6_set_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../data/sources/part6_source.dart';
import '../entities/economy_volume.dart';
import '../entities/part6_passage.dart';

class GeneratePart6SetUseCase {
  const GeneratePart6SetUseCase(this._source);
  final Part6Source _source;

  Future<Part6Set> execute({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) =>
      _source.generate(
        context: context,
        targetLanguage: targetLanguage,
        volumes: volumes,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/domain/use_cases/generate_part6_set_use_case_test.dart`
Expected: PASS — 1/1 test.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/domain/use_cases/generate_part6_set_use_case.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/domain/use_cases/generate_part6_set_use_case.dart test/features/reading/domain/use_cases/generate_part6_set_use_case_test.dart
git commit -m "feat(reading): add GeneratePart6SetUseCase"
```

---

### Task 12: Part6PracticeNotifier

**Files:**
- Create: `lib/features/reading/presentation/providers/part6_practice_provider.dart`
- Create: `lib/features/reading/presentation/providers/part6_practice_provider.g.dart` (generated)
- Test: `test/features/reading/presentation/providers/part6_practice_provider_test.dart`
- Modify: `lib/core/di/app_providers.dart` (add `Part6Source`/`GeneratePart6SetUseCase` providers)

**Interfaces:**
- Consumes: `GeneratePart6SetUseCase` (Task 11, now DI-registered).
- Produces: `Part6SessionResult({required Part6Set set, required List<int?> selectedAnswers})` with `correctCount` getter (iterates passages in order, 4 questions each); `Part6SessionState({required Part6Set set, required List<int?> selectedAnswers, required bool isSubmitted})` with `canSubmit` getter, `copyWith`, and `static int flatIndex(int passageIndex, int questionIndex) => passageIndex * 4 + questionIndex`; `part6PracticeNotifierProvider`; `Part6PracticeNotifier.generate(...)`, `.selectAnswer(int passageIndex, int questionIndex, int optionIndex)`, `.submit()`, `.reset()` — consumed by Tasks 13–15.

- [ ] **Step 1: Register Part6Source/GeneratePart6SetUseCase DI**

In `lib/core/di/app_providers.dart`, add this import block right after the Part 5 imports added in Task 05:

```dart
import '../../features/reading/data/sources/part6_source.dart';
import '../../features/reading/domain/use_cases/generate_part6_set_use_case.dart';
```

Add these providers at the end of the file:

```dart

@riverpod
Part6Source part6Source(Part6SourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return Part6Source(settings);
}

@riverpod
GeneratePart6SetUseCase generatePart6SetUseCase(GeneratePart6SetUseCaseRef ref) =>
    GeneratePart6SetUseCase(ref.watch(part6SourceProvider));
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2: Write the failing test**

Create `test/features/reading/presentation/providers/part6_practice_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part6_set_use_case.dart';
import 'package:lexi_core/features/reading/presentation/providers/part6_practice_provider.dart';

class MockGeneratePart6SetUseCase extends Mock implements GeneratePart6SetUseCase {}

Part6Passage _passage(int i) => Part6Passage(
      passageText: 'Passage $i (1)___ (2)___ (3)___ (4)___.',
      questions: List.generate(
        4,
        (q) => Part6Question(
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Explanation $i-$q',
        ),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  final fixedSet = Part6Set(
    id: 'p1',
    passages: List.generate(3, _passage),
    volumes: const {EconomyVolume.vol4},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  late MockGeneratePart6SetUseCase mockUseCase;
  late ProviderContainer container;

  setUp(() {
    mockUseCase = MockGeneratePart6SetUseCase();
    when(
      () => mockUseCase.execute(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fixedSet);

    container = ProviderContainer(
      overrides: [generatePart6SetUseCaseProvider.overrideWithValue(mockUseCase)],
    );
    addTearDown(container.dispose);
  });

  Future<void> generateFixed() => container.read(part6PracticeNotifierProvider.notifier).generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol4},
      );

  test('generate() populates state with all 12 answers unselected', () async {
    await generateFixed();
    final state = container.read(part6PracticeNotifierProvider).valueOrNull!;
    expect(state.set, same(fixedSet));
    expect(state.selectedAnswers, List<int?>.filled(12, null));
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test('flatIndex maps (passageIndex, questionIndex) to passageIndex*4 + questionIndex', () {
    expect(Part6SessionState.flatIndex(0, 0), 0);
    expect(Part6SessionState.flatIndex(0, 3), 3);
    expect(Part6SessionState.flatIndex(1, 0), 4);
    expect(Part6SessionState.flatIndex(2, 3), 11);
  });

  test('selectAnswer() records an answer at the correct flat index', () async {
    await generateFixed();
    final notifier = container.read(part6PracticeNotifierProvider.notifier);
    notifier.selectAnswer(1, 2, 3); // passage 1, question 2 -> flat index 6
    final state = container.read(part6PracticeNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers[6], 3);
    expect(state.selectedAnswers.where((a) => a != null).length, 1);
  });

  test('canSubmit is true only once all 12 answers are selected', () async {
    await generateFixed();
    final notifier = container.read(part6PracticeNotifierProvider.notifier);
    for (var p = 0; p < 3; p++) {
      for (var q = 0; q < 4; q++) {
        if (p == 2 && q == 3) continue; // leave the last one unanswered
        notifier.selectAnswer(p, q, 0);
      }
    }
    expect(container.read(part6PracticeNotifierProvider).valueOrNull!.canSubmit, false);
    notifier.selectAnswer(2, 3, 0);
    expect(container.read(part6PracticeNotifierProvider).valueOrNull!.canSubmit, true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier = container.read(part6PracticeNotifierProvider.notifier);
    notifier.submit();
    expect(container.read(part6PracticeNotifierProvider).valueOrNull!.isSubmitted, false);
    for (var p = 0; p < 3; p++) {
      for (var q = 0; q < 4; q++) {
        notifier.selectAnswer(p, q, 0);
      }
    }
    notifier.submit();
    expect(container.read(part6PracticeNotifierProvider).valueOrNull!.isSubmitted, true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(part6PracticeNotifierProvider.notifier).reset();
    expect(container.read(part6PracticeNotifierProvider).valueOrNull, isNull);
  });

  test('Part6SessionResult.correctCount counts matching answers across all passages', () {
    // Passage 0's correctIndexes are [0,1,2,3]; passage 1's are [0,1,2,3]; passage 2's are [0,1,2,3].
    // Answer everything with 0: passage 0 gets 1 right (q0), passage 1 gets 1 right (q0),
    // passage 2 gets 1 right (q0) -> 3 total.
    final result = Part6SessionResult(
      set: fixedSet,
      selectedAnswers: List<int?>.filled(12, 0),
    );
    expect(result.correctCount, 3);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/providers/part6_practice_provider_test.dart`
Expected: FAIL — `part6_practice_provider.dart` does not exist.

- [ ] **Step 4: Write the implementation**

Create `lib/features/reading/presentation/providers/part6_practice_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part6_passage.dart';

part 'part6_practice_provider.g.dart';

final class Part6SessionResult {
  const Part6SessionResult({required this.set, required this.selectedAnswers});

  final Part6Set set;
  final List<int?> selectedAnswers; // flat, passage-major order (see Part6SessionState.flatIndex)

  int get correctCount {
    int count = 0;
    var i = 0;
    for (final passage in set.passages) {
      for (final question in passage.questions) {
        if (selectedAnswers[i] == question.correctIndex) count++;
        i++;
      }
    }
    return count;
  }
}

final class Part6SessionState {
  const Part6SessionState({
    required this.set,
    required this.selectedAnswers,
    required this.isSubmitted,
  });

  final Part6Set set;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  bool get canSubmit => selectedAnswers.every((a) => a != null);

  /// Flat index for the [questionIndex]-th blank of [passageIndex] — every
  /// passage always has exactly 4 blanks (enforced by Part6Source's prompt).
  static int flatIndex(int passageIndex, int questionIndex) =>
      passageIndex * 4 + questionIndex;

  Part6SessionState copyWith({List<int?>? selectedAnswers, bool? isSubmitted}) =>
      Part6SessionState(
        set: set,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

@riverpod
class Part6PracticeNotifier extends _$Part6PracticeNotifier {
  @override
  AsyncValue<Part6SessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final set = await ref.read(generatePart6SetUseCaseProvider).execute(
            context: context,
            targetLanguage: targetLanguage,
            volumes: volumes,
          );
      final totalQuestions = set.passages.fold(0, (sum, p) => sum + p.questions.length);
      return Part6SessionState(
        set: set,
        selectedAnswers: List<int?>.filled(totalQuestions, null),
        isSubmitted: false,
      );
    });
  }

  void selectAnswer(int passageIndex, int questionIndex, int optionIndex) {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final updated = List<int?>.from(current.selectedAnswers);
    updated[Part6SessionState.flatIndex(passageIndex, questionIndex)] = optionIndex;
    state = AsyncData(current.copyWith(selectedAnswers: updated));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted || !current.canSubmit) return;
    state = AsyncData(current.copyWith(isSubmitted: true));
  }

  void reset() => state = const AsyncData(null);
}
```

- [ ] **Step 5: Generate Riverpod code and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/reading/presentation/providers/part6_practice_provider_test.dart`
Expected: PASS — 7/7 tests.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/reading/ lib/core/di/app_providers.dart`
Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/reading/presentation/providers/part6_practice_provider.dart \
        lib/features/reading/presentation/providers/part6_practice_provider.g.dart \
        lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart \
        test/features/reading/presentation/providers/part6_practice_provider_test.dart
git commit -m "feat(reading): add Part6PracticeNotifier + DI wiring for Part 6"
```

---

### Task 13: Part6HomeScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part6_home_screen.dart`
- Test: `test/features/reading/presentation/screens/part6_home_screen_test.dart`

**Interfaces:**
- Consumes: `part6PracticeNotifierProvider` (Task 12), `userSettingsNotifierProvider`, `FilterTile`/`showSingleSelectSheet`/`showMultiSelectSheet` (existing) — same shape as Task 06's `Part5HomeScreen`.
- Produces: `Part6HomeScreen` widget — navigates to `/reading/part6/session` on successful generate.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part6_home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part6_home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

Widget _buildHome({required UserSettingsState settings}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part6HomeScreen()),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows AI disabled message when aiEnabled is false', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: false),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tính năng này yêu cầu AI'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI is enabled (no vocab gate)', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });

  testWidgets('shows language, context and difficulty pickers', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Độ khó'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/part6_home_screen_test.dart`
Expected: FAIL — `part6_home_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part6_home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/economy_volume.dart';
import '../providers/part6_practice_provider.dart';

class Part6HomeScreen extends ConsumerStatefulWidget {
  const Part6HomeScreen({super.key});

  @override
  ConsumerState<Part6HomeScreen> createState() => _Part6HomeScreenState();
}

class _Part6HomeScreenState extends ConsumerState<Part6HomeScreen> {
  late Language _language;
  late AppContext _context;
  final Set<EconomyVolume> _volumes = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsNotifierProvider);
    _language = settings.targetLanguage;
    _context = settings.activeContext;
  }

  Future<void> _pickLanguage() async {
    final result = await showSingleSelectSheet<Language>(
      context: context,
      title: 'Ngôn ngữ',
      options: Language.values.map((l) => SelectOption(value: l, label: l.label)).toList(),
      selected: _language,
    );
    if (result != null) setState(() => _language = result.value);
  }

  Future<void> _pickContext() async {
    final result = await showSingleSelectSheet<AppContext>(
      context: context,
      title: 'Chủ đề',
      options: AppContext.values
          .map((c) => SelectOption(value: c, label: c.label, emoji: c.emoji))
          .toList(),
      selected: _context,
    );
    if (result != null) setState(() => _context = result.value);
  }

  Future<void> _pickVolumes() async {
    final result = await showMultiSelectSheet<EconomyVolume>(
      context: context,
      title: 'Độ khó',
      options: EconomyVolume.values.map((v) => SelectOption(value: v, label: v.label)).toList(),
      initialSelected: _volumes,
    );
    if (result != null) {
      setState(() {
        _volumes
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final sessionAsync = ref.watch(part6PracticeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Part 6 — Điền đoạn văn'),
        leading: BackButton(onPressed: () => context.go('/reading')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'AI tạo 3 đoạn văn ngắn (email/thông báo/thư...) mỗi đoạn có 4 chỗ trống '
                'kiểu TOEIC Part 6. Chọn đáp án đúng cho từng chỗ trống.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            FilterTile(
              icon: Icons.language_outlined,
              label: 'Ngôn ngữ',
              value: _language.label,
              onTap: _pickLanguage,
            ),
            FilterTile(
              icon: Icons.sell_outlined,
              label: 'Chủ đề',
              value: '${_context.emoji} ${_context.label}',
              onTap: _pickContext,
            ),
            FilterTile(
              icon: Icons.speed_outlined,
              label: 'Độ khó',
              value: _volumes.isEmpty ? 'Tất cả' : '${_volumes.length} đã chọn',
              onTap: _pickVolumes,
            ),
            const SizedBox(height: 16),
            if (!settings.aiEnabled)
              _ErrorCard(
                message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else
              sessionAsync.when(
                data: (_) => FilledButton.icon(
                  onPressed: () => _generate(context, ref),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Tạo bài luyện'),
                ),
                loading: () => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang tạo bài...'),
                  ],
                ),
                error: (e, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lỗi tạo bài: $e', style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _generate(context, ref),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    await ref.read(part6PracticeNotifierProvider.notifier).generate(
          context: _context,
          targetLanguage: _language,
          volumes: _volumes,
        );
    if (context.mounted) {
      final session = ref.read(part6PracticeNotifierProvider).valueOrNull;
      if (session != null) context.go('/reading/part6/session');
    }
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/part6_home_screen_test.dart`
Expected: PASS — 3/3 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/presentation/screens/part6_home_screen.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part6_home_screen.dart test/features/reading/presentation/screens/part6_home_screen_test.dart
git commit -m "feat(reading): add Part6HomeScreen"
```

---

### Task 14: Part6SessionScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part6_session_screen.dart`
- Test: `test/features/reading/presentation/screens/part6_session_screen_test.dart`

**Interfaces:**
- Consumes: `part6PracticeNotifierProvider`, `Part6SessionState`, `Part6SessionResult`, `Part6SessionState.flatIndex` (Task 12).
- Produces: `Part6SessionScreen` widget — for each of the 3 passages, shows its `passageText` then its 4 question cards; navigates to `/reading/part6/session/result` with a `Part6SessionResult` once `isSubmitted` flips true; navigates back to `/reading/part6` if state is null.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part6_session_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/part6_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part6_session_screen.dart';

Part6Passage _passage(int i) => Part6Passage(
      passageText: 'Passage $i (1)___ (2)___ (3)___ (4)___.',
      questions: List.generate(
        4,
        (q) => Part6Question(
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Explanation $i-$q',
        ),
      ),
    );

final _testSet = Part6Set(
  id: 'test',
  passages: List.generate(3, _passage),
  volumes: const {EconomyVolume.vol4},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _testSession = Part6SessionState(
  set: _testSet,
  selectedAnswers: List<int?>.filled(12, null),
  isSubmitted: false,
);

class _FakePart6Notifier extends Part6PracticeNotifier {
  _FakePart6Notifier(this._session);
  final Part6SessionState _session;

  @override
  AsyncValue<Part6SessionState?> build() => AsyncData(_session);
}

Widget _buildSession({Part6SessionState? session}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part6SessionScreen()),
      GoRoute(
        path: '/reading/part6/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
      ),
      GoRoute(
        path: '/reading/part6',
        builder: (ctx, state) => const Scaffold(body: Text('Part6 home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      part6PracticeNotifierProvider
          .overrideWith(() => _FakePart6Notifier(session ?? _testSession)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows all 3 passage texts', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.textContaining('Passage 0'), findsOneWidget);
    expect(find.textContaining('Passage 1'), findsOneWidget);
    expect(find.textContaining('Passage 2'), findsOneWidget);
  });

  testWidgets('Nộp bài is disabled until all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part6SessionState(
        set: _testSet,
        selectedAnswers: List<int?>.filled(12, 0),
        isSubmitted: false,
      ),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('submitting navigates to the result screen', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part6SessionState(
        set: _testSet,
        selectedAnswers: List<int?>.filled(12, 0),
        isSubmitted: false,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();
    expect(find.text('Result screen'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/part6_session_screen_test.dart`
Expected: FAIL — `part6_session_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part6_session_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/part6_passage.dart';
import '../providers/part6_practice_provider.dart';

class Part6SessionScreen extends ConsumerWidget {
  const Part6SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Part6SessionState?>>(part6PracticeNotifierProvider, (prev, next) {
      final session = next.valueOrNull;
      if (session == null) return;
      if (session.isSubmitted) {
        final result = Part6SessionResult(set: session.set, selectedAnswers: session.selectedAnswers);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/reading/part6/session/result', extra: result);
          }
        });
      }
    });

    final sessionAsync = ref.watch(part6PracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/reading/part6');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (session.isSubmitted) return const Scaffold(body: SizedBox.shrink());
        return _SessionScaffold(session: session);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({required this.session});
  final Part6SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(part6PracticeNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Part 6 — Điền đoạn văn'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var p = 0; p < session.set.passages.length; p++) ...[
                      if (p > 0) const SizedBox(height: 16),
                      _PassageCard(
                        passageIndex: p,
                        passage: session.set.passages[p],
                        selectedAnswers: session.selectedAnswers,
                        onSelected: (questionIndex, optionIndex) =>
                            notifier.selectAnswer(p, questionIndex, optionIndex),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: session.canSubmit ? notifier.submit : null,
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassageCard extends StatelessWidget {
  const _PassageCard({
    required this.passageIndex,
    required this.passage,
    required this.selectedAnswers,
    required this.onSelected,
  });

  final int passageIndex;
  final Part6Passage passage;
  final List<int?> selectedAnswers;
  final void Function(int questionIndex, int optionIndex) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đoạn ${passageIndex + 1}', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(passage.passageText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (var q = 0; q < passage.questions.length; q++) ...[
              if (q > 0) const Divider(height: 1),
              _QuestionGroup(
                blankNumber: q + 1,
                question: passage.questions[q],
                selected: selectedAnswers[Part6SessionState.flatIndex(passageIndex, q)],
                onSelected: (optionIndex) => onSelected(q, optionIndex),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionGroup extends StatelessWidget {
  const _QuestionGroup({
    required this.blankNumber,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int blankNumber;
  final Part6Question question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text('Chỗ trống ($blankNumber)', style: Theme.of(context).textTheme.labelMedium),
        ),
        ...question.options.asMap().entries.map(
              (entry) => RadioListTile<int>(
                value: entry.key,
                groupValue: selected,
                title: Text(entry.value),
                dense: true,
                onChanged: (v) {
                  if (v != null) onSelected(v);
                },
              ),
            ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/part6_session_screen_test.dart`
Expected: PASS — 4/4 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/presentation/screens/part6_session_screen.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part6_session_screen.dart test/features/reading/presentation/screens/part6_session_screen_test.dart
git commit -m "feat(reading): add Part6SessionScreen"
```

---

### Task 15: Part6ResultScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part6_result_screen.dart`
- Test: `test/features/reading/presentation/screens/part6_result_screen_test.dart`

**Interfaces:**
- Consumes: `Part6SessionResult` (Task 12), `statsServiceProvider`, `getVocabSuggestionsForTextUseCaseProvider`, `VocabSuggestionsSection` (existing).
- Produces: `Part6ResultScreen({required Part6SessionResult result})` — "Bài khác" resets and goes to `/reading/part6`; "Về trang chính" resets and goes to `/`.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part6_result_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/part6_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part6_result_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';

class MockStatsService extends Mock implements StatsService {}

class MockGetVocabSuggestionsForTextUseCase extends Mock
    implements GetVocabSuggestionsForTextUseCase {}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

Part6Passage _passage(int i) => Part6Passage(
      passageText: 'Passage $i text (1)___ (2)___ (3)___ (4)___.',
      questions: List.generate(
        4,
        (q) => Part6Question(
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: 0,
          explanation: 'Giải thích $i-$q',
        ),
      ),
    );

final _testSet = Part6Set(
  id: 'p1',
  passages: List.generate(3, _passage),
  volumes: const {EconomyVolume.vol4},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

// Every question's correctIndex is 0. Answer passage 0 all correct (4/4),
// passage 1 all wrong (0/4), passage 2 all correct (4/4) -> 8/12.
final _testResult = Part6SessionResult(
  set: _testSet,
  selectedAnswers: const [0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0],
);

Future<Widget> _buildResult({List<Override> extraOverrides = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => Part6ResultScreen(result: _testResult)),
      GoRoute(path: '/reading/part6', builder: (ctx, state) => const Scaffold(body: Text('Part6 home'))),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults.copyWith(aiEnabled: true)),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  testWidgets('shows the score as correctCount/total', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('8/12'), findsOneWidget);
  });

  testWidgets('shows all 3 passage texts and explanations', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('Passage 0'), findsOneWidget);
    expect(find.textContaining('Passage 1'), findsOneWidget);
    expect(find.textContaining('Passage 2'), findsOneWidget);
    expect(find.textContaining('Giải thích 0-0'), findsOneWidget);
  });

  testWidgets('shows Bài khác and Về trang chính buttons', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Bài khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets('records a practice session with the total question count', (tester) async {
    final mockStats = MockStatsService();
    when(() => mockStats.recordPracticeSession(any())).thenAnswer((_) async {});

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [statsServiceProvider.overrideWithValue(mockStats)],
    ));
    await tester.pumpAndSettle();

    verify(() => mockStats.recordPracticeSession(12)).called(1);
  });

  testWidgets('loads new-word suggestions for the concatenated passage texts with a null CEFR level',
      (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenAnswer((_) async => const WordRadarAiResult(
          translation: '',
          suggestions: [
            WordPhraseResult(
              headword: 'ubiquitous',
              inputType: InputType.word,
              ipa: '/juːˈbɪkwɪtəs/',
              meaning: 'có mặt khắp nơi',
              examples: [],
              suggestedTopics: [],
            ),
          ],
        ));

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions)],
    ));
    await tester.pumpAndSettle();

    verify(() => mockSuggestions.execute(
          text: 'Passage 0 text (1)___ (2)___ (3)___ (4)___. '
              'Passage 1 text (1)___ (2)___ (3)___ (4)___. '
              'Passage 2 text (1)___ (2)___ (3)___ (4)___.',
          targetLanguage: Language.english,
          targetCefrLevel: null,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/part6_result_screen_test.dart`
Expected: FAIL — `part6_result_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part6_result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
import '../../domain/entities/part6_passage.dart';
import '../providers/part6_practice_provider.dart';

class Part6ResultScreen extends ConsumerStatefulWidget {
  const Part6ResultScreen({super.key, required this.result});
  final Part6SessionResult result;

  @override
  ConsumerState<Part6ResultScreen> createState() => _Part6ResultScreenState();
}

class _Part6ResultScreenState extends ConsumerState<Part6ResultScreen> {
  Part6SessionResult get result => widget.result;

  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }

  int get _totalQuestions =>
      result.set.passages.fold(0, (sum, p) => sum + p.questions.length);

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(_totalQuestions);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _passagesText => result.set.passages.map((p) => p.passageText).join(' ');

  Future<void> _loadSuggestions() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final aiResult = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: _passagesText,
            targetLanguage: result.set.targetLanguage,
            targetCefrLevel: null,
          ),
    );
    if (mounted) setState(() => _suggestions = aiResult);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalQuestions;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '${result.correctCount}/$total',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: result.correctCount == total
                      ? Colors.green.shade700
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var p = 0; p < result.set.passages.length; p++) ...[
                      if (p > 0) const SizedBox(height: 16),
                      _PassageBreakdown(
                        passageIndex: p,
                        passage: result.set.passages[p],
                        selectedAnswers: result.selectedAnswers,
                      ),
                    ],
                    _buildSuggestionsSection(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => _regenerate(context, ref), child: const Text('Bài khác')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _goHome(context, ref), child: const Text('Về trang chính')),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(onPressed: _loadSuggestions, child: const Text('Thử lại')),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(part6PracticeNotifierProvider.notifier).reset();
    context.go('/reading/part6');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(part6PracticeNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _PassageBreakdown extends StatelessWidget {
  const _PassageBreakdown({
    required this.passageIndex,
    required this.passage,
    required this.selectedAnswers,
  });

  final int passageIndex;
  final Part6Passage passage;
  final List<int?> selectedAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đoạn ${passageIndex + 1}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(passage.passageText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (var q = 0; q < passage.questions.length; q++)
              _QuestionBreakdown(
                blankNumber: q + 1,
                question: passage.questions[q],
                selected: selectedAnswers[Part6SessionState.flatIndex(passageIndex, q)],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({required this.blankNumber, required this.question, required this.selected});

  final int blankNumber;
  final Part6Question question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = selected == question.correctIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : theme.colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Chỗ trống ($blankNumber)', style: theme.textTheme.titleSmall),
            ],
          ),
          ...question.options.asMap().entries.map((entry) {
            final i = entry.key;
            final isCorrectOption = i == question.correctIndex;
            final isSelectedOption = i == selected;
            Color? color;
            if (isCorrectOption) {
              color = Colors.green;
            } else if (isSelectedOption) {
              color = theme.colorScheme.error;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                entry.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: (isCorrectOption || isSelectedOption) ? FontWeight.bold : null,
                ),
              ),
            );
          }),
          Text(
            'Giải thích: ${question.explanation}',
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/part6_result_screen_test.dart`
Expected: PASS — 5/5 tests.

- [ ] **Step 5: Analyze and run the full reading test slice**

Run: `flutter analyze lib/features/reading/`
Run: `flutter test test/features/reading/`
Expected: no issues; all Part 5 and Part 6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part6_result_screen.dart test/features/reading/presentation/screens/part6_result_screen_test.dart
git commit -m "feat(reading): add Part6ResultScreen (score, explanations, vocab suggestions)"
```

---

### Task 16: Hub Restructure + Router + Practice Card Relabel + README

**Files:**
- Create: `lib/features/reading/presentation/screens/reading_hub_screen.dart`
- Test: `test/features/reading/presentation/screens/reading_hub_screen_test.dart`
- Modify: `lib/features/reading/presentation/screens/reading_home_screen.dart`
- Modify: `lib/features/reading/presentation/screens/reading_session_screen.dart`
- Modify: `lib/features/reading/presentation/screens/reading_result_screen.dart`
- Modify: `test/features/reading/presentation/screens/reading_session_screen_test.dart`
- Modify: `test/features/reading/presentation/screens/reading_result_screen_test.dart`
- Modify: `lib/features/practice/presentation/screens/practice_hub_screen.dart`
- Modify: `test/features/practice/presentation/screens/practice_hub_screen_test.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `README.md`

Note: DI wiring for `Part5Source`/`GeneratePart5SetUseCase` and `Part6Source`/`GeneratePart6SetUseCase` was already added in Tasks 05 and 12 — this task only touches routing, the hub screen, the 3 pre-existing bilingual-reading screens' internal navigation targets, and docs.

**Interfaces:**
- Consumes: `ReadingHomeScreen`/`ReadingSessionScreen`/`ReadingResultScreen` (existing), `Part5HomeScreen`/`Part5SessionScreen`/`Part5ResultScreen` (Tasks 06–08), `Part6HomeScreen`/`Part6SessionScreen`/`Part6ResultScreen` (Tasks 13–15).
- Produces: `ReadingHubScreen` widget; restructured `/reading` routes (`/reading` → hub, `/reading/bilingual/...`, `/reading/part5/...`, `/reading/part6/...`).

- [ ] **Step 1: Write the failing test for ReadingHubScreen**

Create `test/features/reading/presentation/screens/reading_hub_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_hub_screen.dart';

Widget _buildHub() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const ReadingHubScreen()),
      GoRoute(
        path: '/reading/bilingual',
        builder: (ctx, state) => const Scaffold(body: Text('Bilingual home')),
      ),
      GoRoute(
        path: '/reading/part5',
        builder: (ctx, state) => const Scaffold(body: Text('Part5 home')),
      ),
      GoRoute(
        path: '/reading/part6',
        builder: (ctx, state) => const Scaffold(body: Text('Part6 home')),
      ),
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice hub')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows all 3 cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Đọc & gõ'), findsOneWidget);
    expect(find.text('Part 5 — Điền câu'), findsOneWidget);
    expect(find.text('Part 6 — Điền đoạn văn'), findsOneWidget);
  });

  testWidgets('tapping Đọc & gõ navigates to the bilingual home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đọc & gõ'));
    await tester.pumpAndSettle();
    expect(find.text('Bilingual home'), findsOneWidget);
  });

  testWidgets('tapping Part 5 navigates to Part5 home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part 5 — Điền câu'));
    await tester.pumpAndSettle();
    expect(find.text('Part5 home'), findsOneWidget);
  });

  testWidgets('tapping Part 6 navigates to Part6 home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part 6 — Điền đoạn văn'));
    await tester.pumpAndSettle();
    expect(find.text('Part6 home'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/reading_hub_screen_test.dart`
Expected: FAIL — `reading_hub_screen.dart` does not exist.

- [ ] **Step 3: Write ReadingHubScreen**

Create `lib/features/reading/presentation/screens/reading_hub_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReadingHubScreen extends StatelessWidget {
  const ReadingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện đọc'),
        leading: BackButton(onPressed: () => context.go('/practice')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Đọc & gõ'),
              subtitle: const Text(
                'Đọc đoạn văn song ngữ dùng từ vựng của bạn và luyện gõ.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading/bilingual'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.rule_outlined),
              title: const Text('Part 5 — Điền câu'),
              subtitle: const Text(
                '15 câu điền từ/ngữ pháp trắc nghiệm kiểu TOEIC Part 5.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading/part5'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Part 6 — Điền đoạn văn'),
              subtitle: const Text(
                '3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống, kiểu TOEIC Part 6.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading/part6'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/reading_hub_screen_test.dart`
Expected: PASS — 4/4 tests.

- [ ] **Step 5: Update ReadingHomeScreen's navigation now that it's nested under `/reading/bilingual`**

In `lib/features/reading/presentation/screens/reading_home_screen.dart`, change the back button:

```dart
        leading: BackButton(onPressed: () => context.go('/practice')),
```

to:

```dart
        leading: BackButton(onPressed: () => context.go('/reading')),
```

And change the post-generate navigation in `_generate()`:

```dart
      if (session != null && !session.isComplete) {
        context.go('/reading/session');
      }
```

to:

```dart
      if (session != null && !session.isComplete) {
        context.go('/reading/bilingual/session');
      }
```

- [ ] **Step 6: Update ReadingSessionScreen's route strings**

In `lib/features/reading/presentation/screens/reading_session_screen.dart`, change:

```dart
              context.go('/reading/session/result', extra: result);
```

to:

```dart
              context.go('/reading/bilingual/session/result', extra: result);
```

And change:

```dart
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/reading');
          });
```

to:

```dart
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/reading/bilingual');
          });
```

- [ ] **Step 7: Update ReadingResultScreen's regenerate route**

In `lib/features/reading/presentation/screens/reading_result_screen.dart`, in `_regenerate()`, change:

```dart
  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/reading');
  }
```

to:

```dart
  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/reading/bilingual');
  }
```

(`_goHome()`'s `context.go('/')` is unrelated to the reading hub and stays unchanged.)

- [ ] **Step 8: Update the existing reading screen tests' route strings**

In `test/features/reading/presentation/screens/reading_session_screen_test.dart`, change:

```dart
      GoRoute(
        path: '/reading/session/result',
        builder: (ctx, state) =>
            const Scaffold(body: Text('Result screen')),
      ),
```

to:

```dart
      GoRoute(
        path: '/reading/bilingual/session/result',
        builder: (ctx, state) =>
            const Scaffold(body: Text('Result screen')),
      ),
```

In `test/features/reading/presentation/screens/reading_result_screen_test.dart`, there are two identical `GoRoute` blocks (in `_buildResultWithBackspaces()` and `_buildResult()`) — change both occurrences of:

```dart
      GoRoute(
        path: '/reading',
        builder: (ctx, state) => const Scaffold(body: Text('Home')),
      ),
```

to:

```dart
      GoRoute(
        path: '/reading/bilingual',
        builder: (ctx, state) => const Scaffold(body: Text('Home')),
      ),
```

(One of the two blocks in the file has slightly different formatting — `builder: (ctx, state) =>\n            const Scaffold(body: Text('Home')),` on two lines instead of one; apply the same `path:` change to both regardless of that formatting difference.)

Check `test/features/reading/presentation/screens/reading_home_screen_test.dart` for any assertion of the back button's destination (e.g. asserting navigation after tapping a `BackButton`). If none exists (this is the expected case — the file only asserts filter pickers and error/generate states), no change is needed there.

- [ ] **Step 9: Run the full reading test slice to confirm nothing broke**

Run: `flutter test test/features/reading/`
Expected: all tests pass, including the updated `reading_session_screen_test.dart` and `reading_result_screen_test.dart`.

- [ ] **Step 10: Restructure `/reading` routes in app_router.dart**

In `lib/core/router/app_router.dart`, add these imports after the existing reading imports (`reading_home_screen.dart`, `reading_session_screen.dart`, `reading_result_screen.dart`, `reading_practice_provider.dart`):

```dart
import '../../features/reading/presentation/screens/reading_hub_screen.dart';
import '../../features/reading/presentation/screens/part5_home_screen.dart';
import '../../features/reading/presentation/screens/part5_session_screen.dart';
import '../../features/reading/presentation/screens/part5_result_screen.dart';
import '../../features/reading/presentation/providers/part5_practice_provider.dart';
import '../../features/reading/presentation/screens/part6_home_screen.dart';
import '../../features/reading/presentation/screens/part6_session_screen.dart';
import '../../features/reading/presentation/screens/part6_result_screen.dart';
import '../../features/reading/presentation/providers/part6_practice_provider.dart';
```

Replace the existing `/reading` route block:

```dart
        GoRoute(
          path: '/reading',
          builder: (context, state) => const ReadingHomeScreen(),
          routes: [
            GoRoute(
              path: 'session',
              builder: (context, state) => const ReadingSessionScreen(),
              routes: [
                GoRoute(
                  path: 'result',
                  redirect: (context, state) {
                    if (state.extra is! ReadingSessionResult) return '/reading';
                    return null;
                  },
                  builder: (context, state) => ReadingResultScreen(
                    result: state.extra as ReadingSessionResult,
                  ),
                ),
              ],
            ),
          ],
        ),
```

with:

```dart
        GoRoute(
          path: '/reading',
          builder: (context, state) => const ReadingHubScreen(),
          routes: [
            GoRoute(
              path: 'bilingual',
              builder: (context, state) => const ReadingHomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const ReadingSessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! ReadingSessionResult) {
                          return '/reading/bilingual';
                        }
                        return null;
                      },
                      builder: (context, state) => ReadingResultScreen(
                        result: state.extra as ReadingSessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: 'part5',
              builder: (context, state) => const Part5HomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const Part5SessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! Part5SessionResult) return '/reading/part5';
                        return null;
                      },
                      builder: (context, state) => Part5ResultScreen(
                        result: state.extra as Part5SessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: 'part6',
              builder: (context, state) => const Part6HomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const Part6SessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! Part6SessionResult) return '/reading/part6';
                        return null;
                      },
                      builder: (context, state) => Part6ResultScreen(
                        result: state.extra as Part6SessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
```

- [ ] **Step 11: Relabel the "Đọc & gõ" card on PracticeHubScreen**

In `lib/features/practice/presentation/screens/practice_hub_screen.dart`, change:

```dart
              title: const Text('Đọc & gõ'),
              subtitle: const Text(
                'Đọc đoạn văn song ngữ dùng từ vựng của bạn và luyện gõ.',
              ),
```

to:

```dart
              title: const Text('Luyện đọc'),
              subtitle: const Text(
                'Đọc & gõ song ngữ, và luyện đề TOEIC Part 5/6.',
              ),
```

In `test/features/practice/presentation/screens/practice_hub_screen_test.dart`, change:

```dart
    expect(find.text('Đọc & gõ'), findsOneWidget);
```

to:

```dart
    expect(find.text('Luyện đọc'), findsOneWidget);
```

- [ ] **Step 12: Update README.md**

Replace the `### Luyện đọc & gõ (Bilingual Reading Practice)` section:

```markdown
### Luyện đọc & gõ (Bilingual Reading Practice)
- AI tạo đoạn văn 4–6 câu sử dụng từ vựng trong ngân hàng của bạn
- Giao diện song ngữ: câu tiếng mục tiêu + dịch tiếng Việt
- Luyện gõ từng câu — tính WPM (từ/phút) và độ chính xác
- Tô màu từ vựng đã học xuất hiện trong đoạn văn
- Màn hình kết quả: độ chính xác tổng, WPM, danh sách từ đã thực hành
- Truy cập qua tab "Luyện tập" → card "Đọc & gõ"
```

with:

```markdown
### Luyện đọc (Reading Practice)
Hub với 3 tính năng con (truy cập qua tab "Luyện tập" → card "Luyện đọc"):

- **Đọc & gõ (Bilingual Reading Practice)**
  - AI tạo đoạn văn 4–6 câu sử dụng từ vựng trong ngân hàng của bạn
  - Giao diện song ngữ: câu tiếng mục tiêu + dịch tiếng Việt
  - Luyện gõ từng câu — tính WPM (từ/phút) và độ chính xác
  - Tô màu từ vựng đã học xuất hiện trong đoạn văn
  - Màn hình kết quả: độ chính xác tổng, WPM, danh sách từ đã thực hành
- **Part 5 — Điền câu (TOEIC Incomplete Sentences)**
  - AI tạo 15 câu điền từ/ngữ pháp trắc nghiệm 4 đáp án, độc lập với Vocab Bank
  - Hiệu chỉnh độ khó theo **Economy TOEIC Vol 2–5** (chọn nhiều mức cùng lúc, không chọn = tất cả)
  - Trả lời hết 15 câu rồi mới nộp bài; kết quả hiện điểm X/15, giải thích đúng/sai từng câu, gợi ý từ mới
  - Không ảnh hưởng SM-2 — không có từ vựng cụ thể nào để gắn điểm vào
- **Part 6 — Điền đoạn văn (TOEIC Text Completion)**
  - AI tạo 3 đoạn văn ngắn (email/thông báo/thư...), mỗi đoạn 4 chỗ trống trắc nghiệm — luôn có ít nhất 1 chỗ trống dạng "chọn câu phù hợp nhất" mỗi đoạn
  - Cùng cơ chế Economy TOEIC Vol 2–5, trả lời hết 12 câu rồi nộp bài, kết quả X/12 kèm giải thích từng câu và gợi ý từ mới
  - Không ảnh hưởng SM-2
```

Replace the reading section of the `Kiến trúc` file tree:

```markdown
│   ├── reading/
│   │   ├── data/sources/
│   │   │   └── reading_passage_source.dart     # AI passage gen (dùng AiClientFactory)
│   │   ├── domain/
│   │   │   ├── entities/    # ReadingPassage, BilingualSentence
│   │   │   └── use_cases/   # GenerateReadingPassage
│   │   └── presentation/
│   │       ├── providers/   # ReadingPracticeNotifier
│   │       └── screens/     # ReadingHome, ReadingSession, ReadingResult
```

with:

```markdown
│   ├── reading/
│   │   ├── data/sources/
│   │   │   ├── reading_passage_source.dart     # AI passage gen (dùng AiClientFactory)
│   │   │   ├── part5_source.dart                # AI Part 5 gen (TOEIC Incomplete Sentences)
│   │   │   └── part6_source.dart                # AI Part 6 gen (TOEIC Text Completion)
│   │   ├── domain/
│   │   │   ├── entities/    # ReadingPassage, BilingualSentence, EconomyVolume,
│   │   │   │               # Part5Question/Part5Set, Part6Question/Part6Passage/Part6Set
│   │   │   └── use_cases/   # GenerateReadingPassage, GeneratePart5Set, GeneratePart6Set
│   │   └── presentation/
│   │       ├── providers/   # ReadingPracticeNotifier, Part5PracticeNotifier, Part6PracticeNotifier
│   │       └── screens/     # ReadingHub (hub), ReadingHome/Session/Result (bilingual),
│   │                        # Part5Home/Session/Result, Part6Home/Session/Result
```

Replace the `Luồng dữ liệu AI` diagram line:

```markdown
                      ├─ ReadingPassageSource
```

with:

```markdown
                      ├─ ReadingPassageSource
                      ├─ Part5Source
                      ├─ Part6Source
```

- [ ] **Step 13: Analyze, generate, and run the full suite**

```bash
flutter analyze lib/
dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/
flutter test
```

Expected: no analyzer issues; full suite passes (no regressions).

- [ ] **Step 14: Verify web build**

```bash
flutter build web --release
```

Expected: builds successfully.

- [ ] **Step 15: Commit**

```bash
git add lib/features/reading/presentation/screens/reading_hub_screen.dart \
        lib/features/reading/presentation/screens/reading_home_screen.dart \
        lib/features/reading/presentation/screens/reading_session_screen.dart \
        lib/features/reading/presentation/screens/reading_result_screen.dart \
        lib/features/practice/presentation/screens/practice_hub_screen.dart \
        lib/core/router/app_router.dart \
        README.md \
        test/features/reading/presentation/screens/reading_hub_screen_test.dart \
        test/features/reading/presentation/screens/reading_session_screen_test.dart \
        test/features/reading/presentation/screens/reading_result_screen_test.dart \
        test/features/practice/presentation/screens/practice_hub_screen_test.dart
git commit -m "feat(reading): restructure /reading into a hub (Đọc & gõ, Part 5, Part 6)"
```

---
