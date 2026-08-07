# TOEIC Reading Part 7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add TOEIC Reading Part 7 (Reading Comprehension) — 2 single-passage groups (3-4 questions each) + 1 double-passage group (5 questions) per session, ~11-13 questions total — as a 4th card on the existing `/reading` hub.

**Architecture:** New files inside the existing `lib/features/reading/` module, following the exact layering `Part5Source`/`Part6Source` already established: a `Part7Source` calls the shared `AiClientFactory`, validates the AI response's shape before accepting it (the direct fix for the Critical bug the Part 5/6 plan's final review found in `Part6Source`), a `GeneratePart7SetUseCase` wraps it, `Part7PracticeNotifier` holds session state with a *dynamically computed* flat answer index (group sizes vary — 3, 4, or 5 questions — so no fixed multiplier is available even as a wrong shortcut this time), and three screens (home/session/result) reuse the already-built `AiDisabledCard` and `ResultSuggestionsSection` widgets directly.

**Tech Stack:** `AiClientFactory`/`GenerativeModelClient` (existing), Riverpod 2.x `@riverpod`, GoRouter, `uuid`, `flutter_test` + `mocktail`.

**Spec:** [2026-08-07-toeic-reading-part7-design.md](../specs/2026-08-07-toeic-reading-part7-design.md)

## Global Constraints

- Flutter SDK >=3.22.0, Dart >=3.4.0. Riverpod 2.x with `@riverpod` annotation — no `StateNotifier`, no `ChangeNotifier`. Navigation: GoRouter only.
- All domain entities: immutable, `const` constructors.
- AI calls go through `AiClientFactory.buildClient(settings)` / `GenerativeModelClient` (`lib/core/services/ai_client_factory.dart`). Use `parseAiJsonObject` (`lib/core/utils/ai_json_parser.dart`) to decode AI responses.
- **No Vocab Bank dependency, no minimum-word gate, no SM-2 impact** — same as Part 5/6.
- Difficulty is `EconomyVolume` (Vol 2-5, multi-select, empty selection = all 4 volumes, resolved inside `Part7Source`, never by the caller) — the existing enum, no new difficulty concept.
- Every generated `Part7Set` has exactly 3 `passageGroups`, in fixed order: `[single, single, double]`. `passageGroups[0]`/`[1]` have `documents.length == 1` and `questions.length` in `{3, 4}`. `passageGroups[2]` has `documents.length == 2` and `questions.length == 5`.
- `Part7Source` validates this shape before returning a `Part7Set` and throws `FormatException` if the AI response doesn't fit — **do not** let a malformed response reach code that assumes the shape (this is the direct fix for the Part 6 Critical bug: `Part6Source` never validated that every passage had exactly 4 questions, which `Part6SessionState.flatIndex`'s fixed `passageIndex * 4 + questionIndex` formula silently assumed).
- The flat answer index (`Part7SessionState.flatIndex`) is computed by summing each *preceding* group's actual `questions.length` — never a fixed multiplier. Every read/write site of `selectedAnswers` (session screen, result screen, `correctCount`, `selectAnswer`) must go through this one function.
- Every question has an `explanation: String` field (Vietnamese), shown in the result breakdown. The prompt includes the "Vietnamese script only — never Chinese, Japanese, or other non-Vietnamese characters" guard from the start (every other Vietnamese-output AI prompt in this app carries it since commit `3e00740`; Part 5/6 had to patch it in after their own final review flagged it missing).
- Grading is answer-all-then-submit (no per-question live feedback) — `canSubmit` requires every answer non-null; `submit()` is a no-op otherwise.
- Reuse `AiDisabledCard` (`lib/core/widgets/ai_disabled_card.dart`) for the home screen's AI-disabled gate and `ResultSuggestionsSection` (`lib/features/word_radar/presentation/widgets/result_suggestions_section.dart`) for the result screen's new-word suggestions — both already exist, do not recreate them. `statsServiceProvider.recordPracticeSession()` stays inline in the result screen (matches every other part), called with the dynamic total question count.
- After every edit to a file containing `@riverpod`/`@Riverpod` annotations, run `dart run build_runner build --delete-conflicting-outputs` before running tests.
- Run `flutter analyze` and `flutter test` at the end of every task; both must be clean before committing.
- `/reading` is reached only via the "Luyện tập" hub's card, never a bottom-nav destination — `AppShell` is not touched by this plan.

---

## File Structure

```text
lib/features/reading/
├── domain/
│   ├── entities/
│   │   └── part7_passage.dart               CREATE — Part7Question, Part7PassageGroup, Part7Set
│   └── use_cases/
│       └── generate_part7_set_use_case.dart CREATE
├── data/sources/
│   └── part7_source.dart                    CREATE
└── presentation/
    ├── providers/
    │   └── part7_practice_provider.dart     CREATE
    └── screens/
        ├── part7_home_screen.dart           CREATE
        ├── part7_session_screen.dart        CREATE
        ├── part7_result_screen.dart         CREATE
        └── reading_hub_screen.dart          MODIFY — add 4th card

lib/core/di/app_providers.dart          MODIFY — 2 new providers
lib/core/router/app_router.dart         MODIFY — add /reading/part7 routes
README.md                               MODIFY — document Part 7

test/features/reading/
├── domain/entities/part7_passage_test.dart                 CREATE
├── domain/use_cases/generate_part7_set_use_case_test.dart  CREATE
├── data/sources/part7_source_test.dart                     CREATE
├── presentation/providers/part7_practice_provider_test.dart CREATE
└── presentation/screens/
    ├── part7_home_screen_test.dart          CREATE
    ├── part7_session_screen_test.dart       CREATE
    ├── part7_result_screen_test.dart        CREATE
    └── reading_hub_screen_test.dart         MODIFY — assert the 4th card
```

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | Part 7 domain entities | `Part7Question`, `Part7PassageGroup`, `Part7Set` |
| 02 | Part7Source | AI prompt → validated `Part7Set` (3 groups, 1 call) |
| 03 | GeneratePart7SetUseCase | thin wrapper over `Part7Source` |
| 04 | Part7PracticeNotifier + DI | `Part7SessionState` (dynamic `flatIndex`), `Part7SessionResult` |
| 05 | Part7HomeScreen | Ngôn ngữ/Chủ đề/Độ khó filters, `AiDisabledCard`, generate flow |
| 06 | Part7SessionScreen | 3 passage-group cards (1 or 2 documents each), submit gating |
| 07 | Part7ResultScreen | Score X/N, grouped breakdown+explanation, `ResultSuggestionsSection`, stats |
| 08 | Hub + router + README + final verification | 4th `ReadingHubScreen` card, `/reading/part7` routes, docs |

---

### Task 01: Part 7 Domain Entities

**Files:**
- Create: `lib/features/reading/domain/entities/part7_passage.dart`
- Test: `test/features/reading/domain/entities/part7_passage_test.dart`

**Interfaces:**
- Consumes: `AppContext`, `Language` (existing), `EconomyVolume` (existing, `lib/features/reading/domain/entities/economy_volume.dart`).
- Produces: `Part7Question({required String question, required List<String> options, required int correctIndex, required String explanation})`; `Part7PassageGroup({required List<String> documents, required List<Part7Question> questions})`; `Part7Set({required String id, required List<Part7PassageGroup> passageGroups, required Set<EconomyVolume> volumes, required AppContext context, required Language targetLanguage, required DateTime generatedAt})` — consumed by Tasks 02-08.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/domain/entities/part7_passage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';

Part7PassageGroup _singleGroup(int i, int questionCount) => Part7PassageGroup(
      documents: ['Document $i'],
      questions: List.generate(
        questionCount,
        (q) => Part7Question(
          question: 'Question $i-$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Explanation $i-$q',
        ),
      ),
    );

Part7PassageGroup _doubleGroup() => Part7PassageGroup(
      documents: const ['Document A', 'Document B'],
      questions: List.generate(
        5,
        (q) => Part7Question(
          question: 'Double question $q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Double explanation $q',
        ),
      ),
    );

void main() {
  group('Part7Question', () {
    test('holds question, 4 options, correct index, and explanation', () {
      const question = Part7Question(
        question: 'What is the main purpose of this notice?',
        options: ['To announce a delay', 'To request feedback', 'To advertise a sale', 'To confirm a booking'],
        correctIndex: 0,
        explanation: 'Thông báo nói rõ về việc trì hoãn.',
      );
      expect(question.options.length, 4);
      expect(question.correctIndex, 0);
      expect(question.explanation, isNotEmpty);
    });
  });

  group('Part7PassageGroup', () {
    test('a single-passage group has exactly 1 document', () {
      expect(_singleGroup(0, 3).documents.length, 1);
    });

    test('a double-passage group has exactly 2 documents', () {
      expect(_doubleGroup().documents.length, 2);
    });

    test('question count can vary per group (3, 4, or 5)', () {
      expect(_singleGroup(0, 3).questions.length, 3);
      expect(_singleGroup(1, 4).questions.length, 4);
      expect(_doubleGroup().questions.length, 5);
    });
  });

  group('Part7Set', () {
    final set = Part7Set(
      id: 'test-id',
      passageGroups: [_singleGroup(0, 3), _singleGroup(1, 4), _doubleGroup()],
      volumes: const {EconomyVolume.vol4},
      context: AppContext.business,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 8, 7),
    );

    test('always has exactly 3 passage groups', () {
      expect(set.passageGroups.length, 3);
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

Run: `flutter test test/features/reading/domain/entities/part7_passage_test.dart`
Expected: FAIL — `part7_passage.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/domain/entities/part7_passage.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import 'economy_volume.dart';

final class Part7Question {
  const Part7Question({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options; // always 4 items
  final int correctIndex; // 0-3
  final String explanation; // Vietnamese, why the correct option is right
}

final class Part7PassageGroup {
  const Part7PassageGroup({required this.documents, required this.questions});

  final List<String> documents; // 1 (single-passage) or 2 (double-passage)
  final List<Part7Question> questions; // 3-4 for single-passage, 5 for double-passage
}

final class Part7Set {
  const Part7Set({
    required this.id,
    required this.passageGroups,
    required this.volumes,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final List<Part7PassageGroup> passageGroups; // always 3: [single, single, double]
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/domain/entities/part7_passage_test.dart`
Expected: PASS — 7/7 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/domain/entities/part7_passage.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/domain/entities/part7_passage.dart test/features/reading/domain/entities/part7_passage_test.dart
git commit -m "feat(reading): add Part7Question/Part7PassageGroup/Part7Set domain entities"
```

---

### Task 02: Part7Source

**Files:**
- Create: `lib/features/reading/data/sources/part7_source.dart`
- Test: `test/features/reading/data/sources/part7_source_test.dart`

**Interfaces:**
- Consumes: `Part7Question`/`Part7PassageGroup`/`Part7Set` (Task 01), `EconomyVolume` (existing), `AiClientFactory`/`GenerativeModelClient`/`parseAiJsonObject` (existing).
- Produces: `Part7Source(UserSettingsState settings)`, `Part7Source.withModel(GenerativeModelClient client)`, `Future<Part7Set> generate({required AppContext context, required Language targetLanguage, required Set<EconomyVolume> volumes})` — consumed by Task 03.

This is the highest-risk file in the plan: it must validate the AI response's shape before returning, because `Part7SessionState.flatIndex` (Task 04) will trust every group's `questions.length` to be internally consistent with what was actually generated. Read `lib/features/reading/data/sources/part6_source.dart` for the sibling pattern (prompt-building, `_parse`, `FormatException` on empty) — but note Part 6's empty-check alone was NOT enough (that's the Critical bug the Part 5/6 final review found); this task must validate the full shape, not just non-emptiness.

- [ ] **Step 1: Write the failing tests**

Create `test/features/reading/data/sources/part7_source_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part7_source.dart';
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
      'question': 'Question $i?',
      'options': ['a', 'b', 'c', 'd'],
      'correctIndex': i % 4,
      'explanation': 'Explanation $i',
    };

Map<String, dynamic> _singleGroup(int i, int questionCount) => {
      'documents': ['Document $i'],
      'questions': List.generate(questionCount, _question),
    };

Map<String, dynamic> _doubleGroup() => {
      'documents': ['Document A', 'Document B'],
      'questions': List.generate(5, _question),
    };

Map<String, dynamic> _wellFormedResponse() => {
      'passageGroups': [_singleGroup(0, 3), _singleGroup(1, 4), _doubleGroup()],
    };

void main() {
  test('parses a well-formed 3-group response into a Part7Set', () async {
    final json = jsonEncode(_wellFormedResponse());
    final source = Part7Source.withModel(FakeGenerativeModelClient(json));

    final set = await source.generate(
      context: AppContext.business,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );

    expect(set.passageGroups.length, 3);
    expect(set.passageGroups[0].documents.length, 1);
    expect(set.passageGroups[0].questions.length, 3);
    expect(set.passageGroups[1].documents.length, 1);
    expect(set.passageGroups[1].questions.length, 4);
    expect(set.passageGroups[2].documents.length, 2);
    expect(set.passageGroups[2].questions.length, 5);
    expect(set.passageGroups[0].questions[0].explanation, 'Explanation 0');
    expect(set.volumes, {EconomyVolume.vol3});
    expect(set.context, AppContext.business);
    expect(set.targetLanguage, Language.english);
    expect(set.id, isNotEmpty);
  });

  test('throws when the AI response has no passage groups', () async {
    final source = Part7Source.withModel(
      FakeGenerativeModelClient('{"passageGroups":[]}'),
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

  test('throws when a single-passage group has the wrong document count', () async {
    final malformed = {
      'passageGroups': [
        _doubleGroup(), // wrong: group 0 must be single-passage (1 document), not 2
        _singleGroup(1, 4),
        _doubleGroup(),
      ],
    };
    final source = Part7Source.withModel(
      FakeGenerativeModelClient(jsonEncode(malformed)),
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

  test('throws when the double-passage group has the wrong question count', () async {
    final malformed = {
      'passageGroups': [
        _singleGroup(0, 3),
        _singleGroup(1, 4),
        _singleGroup(2, 4), // wrong: group 2 must be double-passage (2 docs, 5 questions)
      ],
    };
    final source = Part7Source.withModel(
      FakeGenerativeModelClient(jsonEncode(malformed)),
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

  test('throws when a single-passage group has an out-of-range question count', () async {
    final malformed = {
      'passageGroups': [
        _singleGroup(0, 2), // wrong: single-passage groups must have 3 or 4 questions, not 2
        _singleGroup(1, 4),
        _doubleGroup(),
      ],
    };
    final source = Part7Source.withModel(
      FakeGenerativeModelClient(jsonEncode(malformed)),
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
    final client = FakeGenerativeModelClient(jsonEncode(_wellFormedResponse()));
    final source = Part7Source.withModel(client);

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

  test('prompt requires the double-passage group to need both documents', () async {
    final client = FakeGenerativeModelClient(jsonEncode(_wellFormedResponse()));
    final source = Part7Source.withModel(client);

    await source.generate(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );

    final part = client.lastPrompt!.first.parts.first as TextPart;
    expect(part.text.toLowerCase(), contains('both'));
  });

  test('prompt includes the Vietnamese-script guard for the explanation field', () async {
    final client = FakeGenerativeModelClient(jsonEncode(_wellFormedResponse()));
    final source = Part7Source.withModel(client);

    await source.generate(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );

    final part = client.lastPrompt!.first.parts.first as TextPart;
    expect(part.text, contains('Vietnamese script'));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/reading/data/sources/part7_source_test.dart`
Expected: FAIL — `part7_source.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/data/sources/part7_source.dart`:

```dart
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part7_passage.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class Part7Source {
  Part7Source(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  Part7Source.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();
  static const _singleQuestionRange = {3, 4};
  static const _doubleQuestionCount = 5;

  Future<Part7Set> generate({
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
    final text = response.text ?? '{"passageGroups":[]}';
    final json = parseAiJsonObject(text);
    final set = _parse(json, effectiveVolumes, context, targetLanguage);
    if (!_hasValidShape(set.passageGroups)) {
      throw const FormatException(
        'AI response produced a malformed Part 7 set (expected 2 single-passage '
        'groups with 3-4 questions each, then 1 double-passage group with exactly '
        '2 documents and 5 questions).',
      );
    }
    return set;
  }

  bool _hasValidShape(List<Part7PassageGroup> groups) {
    if (groups.length != 3) return false;
    for (var i = 0; i < 2; i++) {
      if (groups[i].documents.length != 1) return false;
      if (!_singleQuestionRange.contains(groups[i].questions.length)) return false;
    }
    final doubleGroup = groups[2];
    if (doubleGroup.documents.length != 2) return false;
    if (doubleGroup.questions.length != _doubleQuestionCount) return false;
    return true;
  }

  String _buildPrompt({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) {
    final volumeHints = volumes.map((v) => '${v.label}: ${v.promptHint}').join('; ');
    return 'You are creating a TOEIC Part 7 (Reading Comprehension) practice set for a '
        'Vietnamese speaker learning ${targetLanguage.label}, in a ${context.label} '
        'register/setting, calibrated to the Economy TOEIC difficulty volumes below '
        '(mix questions across them roughly evenly and randomly): $volumeHints. '
        'Write exactly 3 passage groups in this exact order: '
        '(1) a single-passage group: one realistic business document (email, letter, memo, '
        'notice, advertisement, article, or a short text-message exchange), with 3 or 4 '
        'multiple-choice questions; '
        '(2) another single-passage group, same rules, using a different document type than '
        'group 1; '
        '(3) a double-passage group: two genuinely related documents (e.g. a job ad and an '
        'application email, an announcement and a reply, an invoice and a follow-up letter) '
        'where the second document cannot be fully understood without the first, with exactly '
        '5 multiple-choice questions, at least one of which requires information from both '
        'documents to answer. '
        'Every question has exactly 4 answer options in ${targetLanguage.label}, testing main '
        'idea, a specific detail, an inference, or vocabulary-in-context, plus a brief '
        'explanation (in Vietnamese) of why the correct option is right. The explanation must '
        'use only Vietnamese script — never Chinese, Japanese, or other non-Vietnamese '
        'characters. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"passageGroups": [{"documents": ["..."], "questions": [{"question": "...", '
        '"options": ["...", "...", "...", "..."], "correctIndex": 0, "explanation": "..."}]}]}';
  }

  Part7Set _parse(
    Map<String, dynamic> json,
    Set<EconomyVolume> volumes,
    AppContext context,
    Language targetLanguage,
  ) {
    final groups = (json['passageGroups'] as List? ?? []).map((g) {
      final gm = g as Map<String, dynamic>;
      final questions = (gm['questions'] as List? ?? []).map((q) {
        final qm = q as Map<String, dynamic>;
        return Part7Question(
          question: qm['question'] as String? ?? '',
          options: List<String>.from(qm['options'] as List? ?? []),
          correctIndex: qm['correctIndex'] as int? ?? 0,
          explanation: qm['explanation'] as String? ?? '',
        );
      }).toList();
      return Part7PassageGroup(
        documents: List<String>.from(gm['documents'] as List? ?? []),
        questions: questions,
      );
    }).toList();

    return Part7Set(
      id: _uuid.v4(),
      passageGroups: groups,
      volumes: volumes,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reading/data/sources/part7_source_test.dart`
Expected: PASS — 8/8 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/data/sources/part7_source.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/data/sources/part7_source.dart test/features/reading/data/sources/part7_source_test.dart
git commit -m "feat(reading): add Part7Source (AI generation + shape validation for TOEIC Part 7)"
```

---

### Task 03: GeneratePart7SetUseCase

**Files:**
- Create: `lib/features/reading/domain/use_cases/generate_part7_set_use_case.dart`
- Test: `test/features/reading/domain/use_cases/generate_part7_set_use_case_test.dart`

**Interfaces:**
- Consumes: `Part7Source` (Task 02).
- Produces: `GeneratePart7SetUseCase(Part7Source source)`, `Future<Part7Set> execute({required AppContext context, required Language targetLanguage, required Set<EconomyVolume> volumes})` — consumed by Task 04 and Task 08 (DI).

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/domain/use_cases/generate_part7_set_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part7_source.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part7_set_use_case.dart';

class MockPart7Source extends Mock implements Part7Source {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  late MockPart7Source mockSource;
  late GeneratePart7SetUseCase useCase;

  setUp(() {
    mockSource = MockPart7Source();
    useCase = GeneratePart7SetUseCase(mockSource);
  });

  final fakeSet = Part7Set(
    id: 'fake-id',
    passageGroups: const [],
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

Run: `flutter test test/features/reading/domain/use_cases/generate_part7_set_use_case_test.dart`
Expected: FAIL — `generate_part7_set_use_case.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/domain/use_cases/generate_part7_set_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../data/sources/part7_source.dart';
import '../entities/economy_volume.dart';
import '../entities/part7_passage.dart';

class GeneratePart7SetUseCase {
  const GeneratePart7SetUseCase(this._source);
  final Part7Source _source;

  Future<Part7Set> execute({
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

Run: `flutter test test/features/reading/domain/use_cases/generate_part7_set_use_case_test.dart`
Expected: PASS — 1/1 test.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/domain/use_cases/generate_part7_set_use_case.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/domain/use_cases/generate_part7_set_use_case.dart test/features/reading/domain/use_cases/generate_part7_set_use_case_test.dart
git commit -m "feat(reading): add GeneratePart7SetUseCase"
```

---

### Task 04: Part7PracticeNotifier + DI

**Files:**
- Create: `lib/features/reading/presentation/providers/part7_practice_provider.dart`
- Create: `lib/features/reading/presentation/providers/part7_practice_provider.g.dart` (generated)
- Test: `test/features/reading/presentation/providers/part7_practice_provider_test.dart`
- Modify: `lib/core/di/app_providers.dart` (add `Part7Source`/`GeneratePart7SetUseCase` providers)

**Interfaces:**
- Consumes: `GeneratePart7SetUseCase` (Task 03, now DI-registered).
- Produces: `Part7SessionResult({required Part7Set set, required List<int?> selectedAnswers})` with `correctCount` getter; `Part7SessionState({required Part7Set set, required List<int?> selectedAnswers, required bool isSubmitted})` with `canSubmit` getter, `copyWith`, and `static int flatIndex(List<Part7PassageGroup> groups, int groupIndex, int questionIndex)`; `part7PracticeNotifierProvider`; `Part7PracticeNotifier.generate(...)`, `.selectAnswer(int groupIndex, int questionIndex, int optionIndex)`, `.submit()`, `.reset()` — consumed by Tasks 05-08.

**`flatIndex` is the direct fix for the Part 6 Critical bug** — it must NOT hardcode a per-group question count. It sums each *preceding* group's actual `questions.length`:

```dart
static int flatIndex(List<Part7PassageGroup> groups, int groupIndex, int questionIndex) {
  var offset = 0;
  for (var g = 0; g < groupIndex; g++) {
    offset += groups[g].questions.length;
  }
  return offset + questionIndex;
}
```

For a set with group sizes `[3, 4, 5]` (the typical shape): `flatIndex(groups, 0, 0) == 0`, `flatIndex(groups, 1, 0) == 3` (not `4` or any fixed multiple), `flatIndex(groups, 2, 0) == 7`, `flatIndex(groups, 2, 4) == 11` — 12 total slots. The test in Step 2 asserts exactly these values to prove the computation is genuinely dynamic, not a disguised fixed-multiplier.

- [ ] **Step 1: Register Part7Source/GeneratePart7SetUseCase DI (needed for the test container)**

In `lib/core/di/app_providers.dart`, add this import block right after the existing `import '../../features/reading/data/sources/part6_source.dart';` / `import '../../features/reading/domain/use_cases/generate_part6_set_use_case.dart';` lines (inside the `// --- Reading DI (Plan 7) ---` block):

```dart
import '../../features/reading/data/sources/part7_source.dart';
import '../../features/reading/domain/use_cases/generate_part7_set_use_case.dart';
```

Add these providers at the end of the file (after the existing `generatePart6SetUseCase` provider):

```dart

@riverpod
Part7Source part7Source(Part7SourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return Part7Source(settings);
}

@riverpod
GeneratePart7SetUseCase generatePart7SetUseCase(GeneratePart7SetUseCaseRef ref) =>
    GeneratePart7SetUseCase(ref.watch(part7SourceProvider));
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2: Write the failing test**

Create `test/features/reading/presentation/providers/part7_practice_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part7_set_use_case.dart';
import 'package:lexi_core/features/reading/presentation/providers/part7_practice_provider.dart';

class MockGeneratePart7SetUseCase extends Mock implements GeneratePart7SetUseCase {}

Part7PassageGroup _singleGroup(int i, int questionCount) => Part7PassageGroup(
      documents: ['Document $i'],
      questions: List.generate(
        questionCount,
        (q) => Part7Question(
          question: 'Q$i-$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'E$i-$q',
        ),
      ),
    );

Part7PassageGroup _doubleGroup() => Part7PassageGroup(
      documents: const ['Document A', 'Document B'],
      questions: List.generate(
        5,
        (q) => Part7Question(
          question: 'DQ$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'DE$q',
        ),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  // Group sizes are [3, 4, 5] -> 12 total questions, deliberately non-uniform
  // to prove flatIndex is computed dynamically, not via a fixed multiplier.
  final fixedSet = Part7Set(
    id: 'p1',
    passageGroups: [_singleGroup(0, 3), _singleGroup(1, 4), _doubleGroup()],
    volumes: const {EconomyVolume.vol4},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  late MockGeneratePart7SetUseCase mockUseCase;
  late ProviderContainer container;

  setUp(() {
    mockUseCase = MockGeneratePart7SetUseCase();
    when(
      () => mockUseCase.execute(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fixedSet);

    container = ProviderContainer(
      overrides: [generatePart7SetUseCaseProvider.overrideWithValue(mockUseCase)],
    );
    addTearDown(container.dispose);
  });

  Future<void> generateFixed() => container.read(part7PracticeNotifierProvider.notifier).generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol4},
      );

  test('generate() populates state with all 12 answers unselected (3+4+5)', () async {
    await generateFixed();
    final state = container.read(part7PracticeNotifierProvider).valueOrNull!;
    expect(state.set, same(fixedSet));
    expect(state.selectedAnswers, List<int?>.filled(12, null));
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test('flatIndex sums each preceding group\'s actual question count, not a fixed multiplier', () {
    final groups = fixedSet.passageGroups;
    expect(Part7SessionState.flatIndex(groups, 0, 0), 0);
    expect(Part7SessionState.flatIndex(groups, 0, 2), 2);
    expect(Part7SessionState.flatIndex(groups, 1, 0), 3); // group 0 has 3 questions, not 4
    expect(Part7SessionState.flatIndex(groups, 1, 3), 6);
    expect(Part7SessionState.flatIndex(groups, 2, 0), 7); // groups 0+1 = 3+4 = 7
    expect(Part7SessionState.flatIndex(groups, 2, 4), 11);
  });

  test('selectAnswer() records an answer at the correct dynamically-computed flat index', () async {
    await generateFixed();
    final notifier = container.read(part7PracticeNotifierProvider.notifier);
    notifier.selectAnswer(1, 2, 3); // group 1 (offset 3), question 2 -> flat index 5
    final state = container.read(part7PracticeNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers[5], 3);
    expect(state.selectedAnswers.where((a) => a != null).length, 1);
  });

  test('canSubmit is true only once all 12 answers are selected', () async {
    await generateFixed();
    final notifier = container.read(part7PracticeNotifierProvider.notifier);
    final groups = fixedSet.passageGroups;
    for (var g = 0; g < groups.length; g++) {
      for (var q = 0; q < groups[g].questions.length; q++) {
        if (g == 2 && q == 4) continue; // leave the very last one unanswered
        notifier.selectAnswer(g, q, 0);
      }
    }
    expect(container.read(part7PracticeNotifierProvider).valueOrNull!.canSubmit, false);
    notifier.selectAnswer(2, 4, 0);
    expect(container.read(part7PracticeNotifierProvider).valueOrNull!.canSubmit, true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier = container.read(part7PracticeNotifierProvider.notifier);
    notifier.submit();
    expect(container.read(part7PracticeNotifierProvider).valueOrNull!.isSubmitted, false);
    final groups = fixedSet.passageGroups;
    for (var g = 0; g < groups.length; g++) {
      for (var q = 0; q < groups[g].questions.length; q++) {
        notifier.selectAnswer(g, q, 0);
      }
    }
    notifier.submit();
    expect(container.read(part7PracticeNotifierProvider).valueOrNull!.isSubmitted, true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(part7PracticeNotifierProvider.notifier).reset();
    expect(container.read(part7PracticeNotifierProvider).valueOrNull, isNull);
  });

  test('Part7SessionResult.correctCount counts matching answers across non-uniform groups', () {
    // Every group's correctIndexes cycle 0,1,2,3,0(,1). Answer everything with 0:
    // group0 (3 Q) gets 1 right (q0); group1 (4 Q) gets 1 right (q0); group2 (5 Q)
    // gets 2 right (q0 and q4, since correctIndex cycles back to 0 at q4) -> 4 total.
    final result = Part7SessionResult(
      set: fixedSet,
      selectedAnswers: List<int?>.filled(12, 0),
    );
    expect(result.correctCount, 4);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/providers/part7_practice_provider_test.dart`
Expected: FAIL — `part7_practice_provider.dart` does not exist.

- [ ] **Step 4: Write the implementation**

Create `lib/features/reading/presentation/providers/part7_practice_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part7_passage.dart';

part 'part7_practice_provider.g.dart';

final class Part7SessionResult {
  const Part7SessionResult({required this.set, required this.selectedAnswers});

  final Part7Set set;
  final List<int?> selectedAnswers; // flat, group-major order (see Part7SessionState.flatIndex)

  int get correctCount {
    int count = 0;
    for (var g = 0; g < set.passageGroups.length; g++) {
      final questions = set.passageGroups[g].questions;
      for (var q = 0; q < questions.length; q++) {
        final flat = Part7SessionState.flatIndex(set.passageGroups, g, q);
        if (selectedAnswers[flat] == questions[q].correctIndex) count++;
      }
    }
    return count;
  }
}

final class Part7SessionState {
  const Part7SessionState({
    required this.set,
    required this.selectedAnswers,
    required this.isSubmitted,
  });

  final Part7Set set;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  bool get canSubmit => selectedAnswers.every((a) => a != null);

  /// Flat index for the [questionIndex]-th question of [groupIndex], summed
  /// from each preceding group's ACTUAL question count. Single-passage
  /// groups may have 3 or 4 questions — never hardcode a per-group count
  /// here (that was the Part 6 bug this design deliberately avoids).
  static int flatIndex(List<Part7PassageGroup> groups, int groupIndex, int questionIndex) {
    var offset = 0;
    for (var g = 0; g < groupIndex; g++) {
      offset += groups[g].questions.length;
    }
    return offset + questionIndex;
  }

  Part7SessionState copyWith({List<int?>? selectedAnswers, bool? isSubmitted}) =>
      Part7SessionState(
        set: set,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

@riverpod
class Part7PracticeNotifier extends _$Part7PracticeNotifier {
  @override
  AsyncValue<Part7SessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final set = await ref.read(generatePart7SetUseCaseProvider).execute(
            context: context,
            targetLanguage: targetLanguage,
            volumes: volumes,
          );
      final totalQuestions = set.passageGroups.fold(0, (sum, g) => sum + g.questions.length);
      return Part7SessionState(
        set: set,
        selectedAnswers: List<int?>.filled(totalQuestions, null),
        isSubmitted: false,
      );
    });
  }

  void selectAnswer(int groupIndex, int questionIndex, int optionIndex) {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final updated = List<int?>.from(current.selectedAnswers);
    final flat = Part7SessionState.flatIndex(current.set.passageGroups, groupIndex, questionIndex);
    updated[flat] = optionIndex;
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
Run: `flutter test test/features/reading/presentation/providers/part7_practice_provider_test.dart`
Expected: PASS — 7/7 tests.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/reading/ lib/core/di/app_providers.dart`
Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/reading/presentation/providers/part7_practice_provider.dart \
        lib/features/reading/presentation/providers/part7_practice_provider.g.dart \
        lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart \
        test/features/reading/presentation/providers/part7_practice_provider_test.dart
git commit -m "feat(reading): add Part7PracticeNotifier (dynamic flatIndex) + DI wiring for Part 7"
```

---

### Task 05: Part7HomeScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part7_home_screen.dart`
- Test: `test/features/reading/presentation/screens/part7_home_screen_test.dart`

**Interfaces:**
- Consumes: `part7PracticeNotifierProvider` (Task 04), `userSettingsNotifierProvider` (existing), `FilterTile`/`showSingleSelectSheet`/`showMultiSelectSheet` (existing, `lib/core/widgets/`), `AiDisabledCard` (existing, `lib/core/widgets/ai_disabled_card.dart`).
- Produces: `Part7HomeScreen` widget — navigates to `/reading/part7/session` on successful generate (route added in Task 08; this task's widget test registers its own stub route so it doesn't depend on Task 08).

This is identical in shape to `lib/features/reading/presentation/screens/part5_home_screen.dart` (read it for reference) — only the title, description text, provider, and target route differ.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part7_home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part7_home_screen.dart';
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
      GoRoute(path: '/', builder: (ctx, state) => const Part7HomeScreen()),
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

Run: `flutter test test/features/reading/presentation/screens/part7_home_screen_test.dart`
Expected: FAIL — `part7_home_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part7_home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/ai_disabled_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/economy_volume.dart';
import '../providers/part7_practice_provider.dart';

class Part7HomeScreen extends ConsumerStatefulWidget {
  const Part7HomeScreen({super.key});

  @override
  ConsumerState<Part7HomeScreen> createState() => _Part7HomeScreenState();
}

class _Part7HomeScreenState extends ConsumerState<Part7HomeScreen> {
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
    final sessionAsync = ref.watch(part7PracticeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Part 7 — Đọc hiểu'),
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
                'AI tạo 2 đoạn văn đơn + 1 bộ đoạn văn đôi (2 văn bản liên quan), kèm câu hỏi '
                'trắc nghiệm kiểu TOEIC Part 7. Trả lời hết rồi nộp bài.',
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
              AiDisabledCard(
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
    await ref.read(part7PracticeNotifierProvider.notifier).generate(
          context: _context,
          targetLanguage: _language,
          volumes: _volumes,
        );
    if (context.mounted) {
      final session = ref.read(part7PracticeNotifierProvider).valueOrNull;
      if (session != null) context.go('/reading/part7/session');
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/part7_home_screen_test.dart`
Expected: PASS — 3/3 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/presentation/screens/part7_home_screen.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part7_home_screen.dart test/features/reading/presentation/screens/part7_home_screen_test.dart
git commit -m "feat(reading): add Part7HomeScreen"
```

---

### Task 06: Part7SessionScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part7_session_screen.dart`
- Test: `test/features/reading/presentation/screens/part7_session_screen_test.dart`

**Interfaces:**
- Consumes: `part7PracticeNotifierProvider`, `Part7SessionState`, `Part7SessionResult`, `Part7SessionState.flatIndex` (Task 04).
- Produces: `Part7SessionScreen` widget — for each of the 3 passage groups in order, shows 1 or 2 document cards (`group.documents.length` decides which) followed by that group's question cards; navigates to `/reading/part7/session/result` with a `Part7SessionResult` once `isSubmitted` flips true; navigates back to `/reading/part7` if state is null.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part7_session_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/part7_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part7_session_screen.dart';

Part7PassageGroup _singleGroup(int i, int questionCount) => Part7PassageGroup(
      documents: ['Document $i'],
      questions: List.generate(
        questionCount,
        (q) => Part7Question(
          question: 'Q$i-$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'E$i-$q',
        ),
      ),
    );

Part7PassageGroup _doubleGroup() => Part7PassageGroup(
      documents: const ['Document A', 'Document B'],
      questions: List.generate(
        5,
        (q) => Part7Question(
          question: 'DQ$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'DE$q',
        ),
      ),
    );

final _testSet = Part7Set(
  id: 'test',
  passageGroups: [_singleGroup(0, 3), _singleGroup(1, 4), _doubleGroup()],
  volumes: const {EconomyVolume.vol4},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _testSession = Part7SessionState(
  set: _testSet,
  selectedAnswers: List<int?>.filled(12, null),
  isSubmitted: false,
);

class _FakePart7Notifier extends Part7PracticeNotifier {
  _FakePart7Notifier(this._session);
  final Part7SessionState _session;

  @override
  AsyncValue<Part7SessionState?> build() => AsyncData(_session);
}

Widget _buildSession({Part7SessionState? session}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part7SessionScreen()),
      GoRoute(
        path: '/reading/part7/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
      ),
      GoRoute(
        path: '/reading/part7',
        builder: (ctx, state) => const Scaffold(body: Text('Part7 home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      part7PracticeNotifierProvider
          .overrideWith(() => _FakePart7Notifier(session ?? _testSession)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows all 3 groups\' documents, including both documents of the double-passage group',
      (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.textContaining('Document 0'), findsOneWidget);
    expect(find.textContaining('Document 1'), findsOneWidget);
    expect(find.textContaining('Document A'), findsOneWidget);
    expect(find.textContaining('Document B'), findsOneWidget);
  });

  testWidgets('Nộp bài is disabled until all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part7SessionState(set: _testSet, selectedAnswers: List<int?>.filled(12, 0), isSubmitted: false),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('submitting navigates to the result screen', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part7SessionState(set: _testSet, selectedAnswers: List<int?>.filled(12, 0), isSubmitted: false),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();
    expect(find.text('Result screen'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/part7_session_screen_test.dart`
Expected: FAIL — `part7_session_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part7_session_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/part7_passage.dart';
import '../providers/part7_practice_provider.dart';

class Part7SessionScreen extends ConsumerWidget {
  const Part7SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Part7SessionState?>>(part7PracticeNotifierProvider, (prev, next) {
      final session = next.valueOrNull;
      if (session == null) return;
      if (session.isSubmitted) {
        final result = Part7SessionResult(set: session.set, selectedAnswers: session.selectedAnswers);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/reading/part7/session/result', extra: result);
          }
        });
      }
    });

    final sessionAsync = ref.watch(part7PracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/reading/part7');
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
  final Part7SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(part7PracticeNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Part 7 — Đọc hiểu'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var g = 0; g < session.set.passageGroups.length; g++) ...[
                      if (g > 0) const SizedBox(height: 16),
                      _PassageGroupCard(
                        groupIndex: g,
                        group: session.set.passageGroups[g],
                        allGroups: session.set.passageGroups,
                        selectedAnswers: session.selectedAnswers,
                        onSelected: (questionIndex, optionIndex) =>
                            notifier.selectAnswer(g, questionIndex, optionIndex),
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

class _PassageGroupCard extends StatelessWidget {
  const _PassageGroupCard({
    required this.groupIndex,
    required this.group,
    required this.allGroups,
    required this.selectedAnswers,
    required this.onSelected,
  });

  final int groupIndex;
  final Part7PassageGroup group;
  final List<Part7PassageGroup> allGroups;
  final List<int?> selectedAnswers;
  final void Function(int questionIndex, int optionIndex) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDouble = group.documents.length == 2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDouble ? 'Đoạn ${groupIndex + 1} (2 văn bản liên quan)' : 'Đoạn ${groupIndex + 1}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var d = 0; d < group.documents.length; d++) ...[
              if (d > 0) const SizedBox(height: 12),
              Text(
                group.documents[d],
                style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
              ),
            ],
            const SizedBox(height: 8),
            for (var q = 0; q < group.questions.length; q++) ...[
              if (q > 0) const Divider(height: 1),
              _QuestionGroup(
                questionNumber: q + 1,
                question: group.questions[q],
                selected: selectedAnswers[Part7SessionState.flatIndex(allGroups, groupIndex, q)],
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
    required this.questionNumber,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int questionNumber;
  final Part7Question question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            '$questionNumber. ${question.question}',
            style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
          ),
        ),
        ...question.options.asMap().entries.map(
              (entry) => RadioListTile<int>(
                value: entry.key,
                groupValue: selected,
                title: Text(
                  entry.value,
                  style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
                ),
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

Run: `flutter test test/features/reading/presentation/screens/part7_session_screen_test.dart`
Expected: PASS — 4/4 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/reading/presentation/screens/part7_session_screen.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part7_session_screen.dart test/features/reading/presentation/screens/part7_session_screen_test.dart
git commit -m "feat(reading): add Part7SessionScreen"
```

---

### Task 07: Part7ResultScreen

**Files:**
- Create: `lib/features/reading/presentation/screens/part7_result_screen.dart`
- Test: `test/features/reading/presentation/screens/part7_result_screen_test.dart`

**Interfaces:**
- Consumes: `Part7SessionResult` (Task 04), `statsServiceProvider` (existing, `lib/core/di/app_providers.dart`), `ResultSuggestionsSection` (existing, `lib/features/word_radar/presentation/widgets/result_suggestions_section.dart` — reused directly, do not recreate its loading/error/retry logic).
- Produces: `Part7ResultScreen({required Part7SessionResult result})` — "Bài khác" resets and goes to `/reading/part7`; "Về trang chính" resets and goes to `/`.

This is the same shape as `lib/features/reading/presentation/screens/part6_result_screen.dart` (read it for reference — it already uses `ResultSuggestionsSection`, not the old inline trio), except the breakdown is grouped by `passageGroups` (1 or 2 documents each) instead of `passages`, and the total question count is `passageGroups.fold(0, (sum, g) => sum + g.questions.length)` rather than a fixed constant.

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/presentation/screens/part7_result_screen_test.dart`:

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
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/part7_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part7_result_screen.dart';
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

Part7PassageGroup _group(int i, int questionCount, {int documentCount = 1}) => Part7PassageGroup(
      documents: List.generate(documentCount, (d) => 'Document $i-$d'),
      questions: List.generate(
        questionCount,
        (q) => Part7Question(
          question: 'Q$i-$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: 0,
          explanation: 'Vì đáp án A đúng ($i-$q).',
        ),
      ),
    );

final _testSet = Part7Set(
  id: 'p1',
  passageGroups: [
    _group(0, 3),
    _group(1, 4),
    _group(2, 5, documentCount: 2),
  ],
  volumes: const {EconomyVolume.vol4},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

// Every question's correctIndex is 0. Answer group 0 all correct (3/3),
// group 1 all wrong (0/4), group 2 all correct (5/5) -> 8/12.
final _testResult = Part7SessionResult(
  set: _testSet,
  selectedAnswers: const [0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0],
);

Future<Widget> _buildResult({List<Override> extraOverrides = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => Part7ResultScreen(result: _testResult)),
      GoRoute(path: '/reading/part7', builder: (ctx, state) => const Scaffold(body: Text('Part7 home'))),
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

  testWidgets('shows the score as correctCount/total (computed dynamically, not a fixed constant)',
      (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('8/12'), findsOneWidget);
  });

  testWidgets('shows all group documents (including both documents of the double-passage group) and explanations',
      (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('Document 0-0'), findsOneWidget);
    expect(find.textContaining('Document 1-0'), findsOneWidget);
    expect(find.textContaining('Document 2-0'), findsOneWidget);
    expect(find.textContaining('Document 2-1'), findsOneWidget);
    expect(find.textContaining('Vì đáp án A đúng (0-0).'), findsOneWidget);
  });

  testWidgets('shows Bài khác and Về trang chính buttons', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Bài khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets('records a practice session with the dynamically-computed total question count',
      (tester) async {
    final mockStats = MockStatsService();
    when(() => mockStats.recordPracticeSession(any())).thenAnswer((_) async {});

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [statsServiceProvider.overrideWithValue(mockStats)],
    ));
    await tester.pumpAndSettle();

    verify(() => mockStats.recordPracticeSession(12)).called(1);
  });

  testWidgets('loads new-word suggestions for the concatenated text of every document across all groups',
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
          text: 'Document 0-0 Document 1-0 Document 2-0 Document 2-1',
          targetLanguage: Language.english,
          targetCefrLevel: null,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reading/presentation/screens/part7_result_screen_test.dart`
Expected: FAIL — `part7_result_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reading/presentation/screens/part7_result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../../domain/entities/part7_passage.dart';
import '../providers/part7_practice_provider.dart';

class Part7ResultScreen extends ConsumerStatefulWidget {
  const Part7ResultScreen({super.key, required this.result});
  final Part7SessionResult result;

  @override
  ConsumerState<Part7ResultScreen> createState() => _Part7ResultScreenState();
}

class _Part7ResultScreenState extends ConsumerState<Part7ResultScreen> {
  Part7SessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  int get _totalQuestions =>
      result.set.passageGroups.fold(0, (sum, g) => sum + g.questions.length);

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(_totalQuestions);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _documentsText =>
      result.set.passageGroups.expand((g) => g.documents).join(' ');

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
                    for (var g = 0; g < result.set.passageGroups.length; g++) ...[
                      if (g > 0) const SizedBox(height: 16),
                      _PassageGroupBreakdown(
                        groupIndex: g,
                        group: result.set.passageGroups[g],
                        allGroups: result.set.passageGroups,
                        selectedAnswers: result.selectedAnswers,
                      ),
                    ],
                    ResultSuggestionsSection(
                      text: _documentsText,
                      targetLanguage: result.set.targetLanguage,
                      targetCefrLevel: null,
                    ),
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

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(part7PracticeNotifierProvider.notifier).reset();
    context.go('/reading/part7');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(part7PracticeNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _PassageGroupBreakdown extends StatelessWidget {
  const _PassageGroupBreakdown({
    required this.groupIndex,
    required this.group,
    required this.allGroups,
    required this.selectedAnswers,
  });

  final int groupIndex;
  final Part7PassageGroup group;
  final List<Part7PassageGroup> allGroups;
  final List<int?> selectedAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDouble = group.documents.length == 2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDouble ? 'Đoạn ${groupIndex + 1} (2 văn bản liên quan)' : 'Đoạn ${groupIndex + 1}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var d = 0; d < group.documents.length; d++) ...[
              if (d > 0) const SizedBox(height: 12),
              Text(
                group.documents[d],
                style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
              ),
            ],
            const SizedBox(height: 8),
            for (var q = 0; q < group.questions.length; q++)
              _QuestionBreakdown(
                questionNumber: q + 1,
                question: group.questions[q],
                selected: selectedAnswers[Part7SessionState.flatIndex(allGroups, groupIndex, q)],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({required this.questionNumber, required this.question, required this.selected});

  final int questionNumber;
  final Part7Question question;
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
              Expanded(
                child: Text(
                  '$questionNumber. ${question.question}',
                  style: webScaled(theme.textTheme.titleSmall ?? const TextStyle(fontSize: 14)),
                ),
              ),
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
                style: webScaled(
                  (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
                    color: color,
                    fontWeight: (isCorrectOption || isSelectedOption) ? FontWeight.bold : null,
                  ),
                ),
              ),
            );
          }),
          Text(
            'Giải thích: ${question.explanation}',
            style: webScaled(
              (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12))
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reading/presentation/screens/part7_result_screen_test.dart`
Expected: PASS — 5/5 tests.

- [ ] **Step 5: Analyze and run the full reading test slice**

Run: `flutter analyze lib/features/reading/`
Run: `flutter test test/features/reading/`
Expected: no issues; all Part 7 tests plus the pre-existing Reading/Part5/Part6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/screens/part7_result_screen.dart test/features/reading/presentation/screens/part7_result_screen_test.dart
git commit -m "feat(reading): add Part7ResultScreen (dynamic score, explanations, vocab suggestions)"
```

---

### Task 08: Hub Card + Router + README + Final Verification

**Files:**
- Modify: `lib/features/reading/presentation/screens/reading_hub_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `README.md`
- Modify: `test/features/reading/presentation/screens/reading_hub_screen_test.dart`

Note: DI wiring for `Part7Source`/`GeneratePart7SetUseCase` was already added in Task 04 — this task only touches the hub screen, routing, and docs.

**Interfaces:**
- Consumes: `Part7HomeScreen`/`Part7SessionScreen`/`Part7ResultScreen` (Tasks 05-07).
- Produces: `ReadingHubScreen` with a 4th card; `/reading/part7`, `/reading/part7/session`, `/reading/part7/session/result` routes.

- [ ] **Step 1: Add the 4th card to `ReadingHubScreen`**

In `lib/features/reading/presentation/screens/reading_hub_screen.dart`, the `body: ListView(...)`'s `children` list currently ends with the Part 6 card:

```dart
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

Change it to add a 4th card after Part 6's, before the closing `],`:

```dart
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
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dynamic_feed_outlined),
              title: const Text('Part 7 — Đọc hiểu'),
              subtitle: const Text(
                '2 đoạn văn đơn + 1 bộ đoạn đôi, kèm câu hỏi trắc nghiệm kiểu TOEIC Part 7.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading/part7'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update `reading_hub_screen_test.dart` to assert the 4th card**

Replace the whole file `test/features/reading/presentation/screens/reading_hub_screen_test.dart` with:

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
        path: '/reading/part7',
        builder: (ctx, state) => const Scaffold(body: Text('Part7 home')),
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
  testWidgets('shows all 4 cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Đọc & gõ'), findsOneWidget);
    expect(find.text('Part 5 — Điền câu'), findsOneWidget);
    expect(find.text('Part 6 — Điền đoạn văn'), findsOneWidget);
    expect(find.text('Part 7 — Đọc hiểu'), findsOneWidget);
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

  testWidgets('tapping Part 7 navigates to Part7 home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part 7 — Đọc hiểu'));
    await tester.pumpAndSettle();
    expect(find.text('Part7 home'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the hub screen test**

Run: `flutter test test/features/reading/presentation/screens/reading_hub_screen_test.dart`
Expected: PASS — 5/5 tests.

- [ ] **Step 4: Add `/reading/part7` routes to `app_router.dart`**

In `lib/core/router/app_router.dart`, add these imports after the existing Part 6 imports (`import '../../features/reading/presentation/providers/part6_practice_provider.dart';`):

```dart
import '../../features/reading/presentation/screens/part7_home_screen.dart';
import '../../features/reading/presentation/screens/part7_session_screen.dart';
import '../../features/reading/presentation/screens/part7_result_screen.dart';
import '../../features/reading/presentation/providers/part7_practice_provider.dart';
```

Inside the `/reading` route's nested `routes: [...]` list, add a `part7` sibling route immediately after the existing `part6` route block (before the closing `],` of the `/reading` route's own `routes` list):

```dart
            GoRoute(
              path: 'part7',
              builder: (context, state) => const Part7HomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const Part7SessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! Part7SessionResult) return '/reading/part7';
                        return null;
                      },
                      builder: (context, state) => Part7ResultScreen(
                        result: state.extra as Part7SessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
```

- [ ] **Step 5: Update README.md**

Replace the `### Luyện đọc (Reading Practice)` section's opening line and Part 6 bullet block:

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

with:

```markdown
### Luyện đọc (Reading Practice)
Hub với 4 tính năng con (truy cập qua tab "Luyện tập" → card "Luyện đọc"):

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
- **Part 7 — Đọc hiểu (TOEIC Reading Comprehension)**
  - AI tạo 2 đoạn văn đơn (3–4 câu hỏi/đoạn) + 1 bộ đoạn văn đôi (2 văn bản liên quan, 5 câu hỏi, ít nhất 1 câu cần đối chiếu cả 2 văn bản) — tổng ~11–13 câu/phiên
  - Cùng cơ chế Economy TOEIC Vol 2–5, trả lời hết rồi nộp bài, kết quả X/N (N tính động theo số câu thực tế) kèm giải thích từng câu và gợi ý từ mới
  - Không ảnh hưởng SM-2
```

Replace the reading section of the `Kiến trúc` file tree:

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
```

with:

```markdown
│   ├── reading/
│   │   ├── data/sources/
│   │   │   ├── reading_passage_source.dart     # AI passage gen (dùng AiClientFactory)
│   │   │   ├── part5_source.dart                # AI Part 5 gen (TOEIC Incomplete Sentences)
│   │   │   ├── part6_source.dart                # AI Part 6 gen (TOEIC Text Completion)
│   │   │   └── part7_source.dart                # AI Part 7 gen + shape validation (TOEIC Reading Comprehension)
│   │   ├── domain/
│   │   │   ├── entities/    # ReadingPassage, BilingualSentence, EconomyVolume,
│   │   │   │               # Part5Question/Part5Set, Part6Question/Part6Passage/Part6Set,
│   │   │   │               # Part7Question/Part7PassageGroup/Part7Set
│   │   │   └── use_cases/   # GenerateReadingPassage, GeneratePart5Set, GeneratePart6Set, GeneratePart7Set
│   │   └── presentation/
│   │       ├── providers/   # ReadingPracticeNotifier, Part5PracticeNotifier, Part6PracticeNotifier,
│   │       │               # Part7PracticeNotifier
│   │       └── screens/     # ReadingHub (hub), ReadingHome/Session/Result (bilingual),
```

Replace the `Luồng dữ liệu AI` diagram line:

```markdown
                      ├─ ReadingPassageSource
                      ├─ Part5Source
                      ├─ Part6Source
```

with:

```markdown
                      ├─ ReadingPassageSource
                      ├─ Part5Source
                      ├─ Part6Source
                      ├─ Part7Source
```

- [ ] **Step 6: Full-project analyze, regenerate codegen, full test suite, web build**

```bash
flutter analyze lib/
dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/
flutter test
flutter build web --release
```

Expected: no analyzer issues beyond the pre-existing, unrelated `RadioListTile`/`RadioGroup` deprecation infos already known from earlier work; full suite green; web build succeeds. **Note the exact passing test count from this run** — you'll need it for the next step.

- [ ] **Step 7: Update the README test count with the actual number from Step 6**

Find this line in `README.md`:

```markdown
Hiện tại: **432 tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

Replace `432` with the exact total `flutter test` reported in Step 6 (e.g. if Step 6 reported `+479: All tests passed!`, use `479`). Do not guess this number — use the real count from the run you just did.

- [ ] **Step 8: Commit**

```bash
git add lib/features/reading/presentation/screens/reading_hub_screen.dart \
        lib/core/router/app_router.dart \
        README.md \
        test/features/reading/presentation/screens/reading_hub_screen_test.dart
git commit -m "feat(reading): add Part 7 to the reading hub, router, and docs"
```

---
