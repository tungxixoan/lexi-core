# SM-2 practice mode toggle (Flashcard vs Trộn AI) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The SM-2 practice setup screen (Flutter `practice_home_screen.dart`, web `/practice`) gains a session-level "Flashcard" (default) vs "Trộn AI" toggle. Flashcard forces every word to the flashcard exercise; Trộn AI draws one random AI-mix ratio in [0.20, 0.80] per session and uses it for the existing per-word coin flip. The choice is never persisted — the setup screen always opens on Flashcard.

**Architecture:** Replace the hardcoded 30%-flashcard/70%-AI literal on both platforms with an explicit `aiRatio` (0.0–1.0) value threaded from the setup screen into the session. `aiRatio = 0` for Flashcard mode; `aiRatio` = one random draw in [0.20, 0.80] for Trộn AI, computed once at session start. The `sm2Repetitions == 0` / no-AI-key override is untouched. Both the ratio-decision (`shouldUseFlashcard`) and the ratio-draw (`drawSessionAiRatio`) become small pure functions, so they're unit-testable with plain numbers (no RNG mocking needed on the Flutter side; the existing `rng: () => number` convention is kept on web).

**Tech Stack:** Flutter (Riverpod), Next.js/React (`apps/web/`), Vitest + `flutter_test`.

## Global Constraints

- **Formula (both platforms), replacing the old `roll < 0.30` / `rng() < 0.3` literal:**
  `flashcardProb = 1 - aiRatio`; word is flashcard iff `roll < flashcardProb` (after the rep/AI-availability override). With `aiRatio = 0.7` this reproduces today's exact 30/70 behavior — confirms the refactor is behavior-preserving for existing tests.
- **`aiRatio` draw:** `0.20 + roll * 0.60` where `roll` is a fresh random value in `[0, 1)`, drawn **once per session** (not per word, not re-drawn on a later grade).
- **The `sm2Repetitions == 0 || !aiAvailable → always flashcard` override is unchanged** and is checked *before* consulting `aiRatio`.
- **Not persisted anywhere** (no Settings, no SharedPreferences/localStorage) — every fresh mount of the setup screen defaults to Flashcard.
- **`progress_screen.dart`'s "Ôn hôm nay" quick-start** (Tiến độ tab, bypasses the setup screen entirely) always uses `aiRatio: 0.0` (Flashcard) — it has no UI of its own for this toggle and this plan does not add one there.
- Labels: **"Flashcard"** / **"Trộn AI"** on both platforms, verbatim.
- `flutter analyze` stays 0. Web `npm run typecheck` stays clean. Tests only go up (Flutter 909, web 795 at plan start).
- `apps/web/` changes only touch `apps/web/`; Flutter changes only touch the Flutter tree.
- Commit trailer: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## File Structure

**Modified (Flutter):**
- `lib/features/practice/domain/entities/exercise_result.dart` — `SessionConfig.aiRatio`, `shouldUseFlashcard`, `drawSessionAiRatio`
- `lib/features/practice/presentation/providers/practice_session_provider.dart` — `PracticeSessionState.aiRatio`, wiring
- `lib/features/practice/presentation/screens/practice_home_screen.dart` — mode toggle UI
- `lib/features/practice/presentation/screens/progress_screen.dart` — one-line fix
- `test/features/practice/presentation/screens/practice_session_screen_test.dart` — fix 2 call sites
- `test/features/practice/presentation/screens/practice_home_screen_test.dart` — new tests

**Created (Flutter):**
- `test/features/practice/domain/entities/exercise_result_test.dart`
- `test/features/practice/presentation/providers/practice_session_provider_test.dart`

**Modified (web):**
- `apps/web/src/lib/pickExercise.ts` — `aiRatio` param, `drawSessionAiRatio`
- `apps/web/src/lib/pickExercise.test.ts` — updated + new tests
- `apps/web/src/app/(app)/practice/page.tsx` — mode toggle UI + wiring
- `apps/web/src/app/(app)/practice/page.test.tsx` — updated + new tests

---

## Task 1: Flutter — `SessionConfig.aiRatio` + pure decision functions

**Files:**
- Modify: `lib/features/practice/domain/entities/exercise_result.dart`
- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart` (2 call sites — placeholder value, real wiring comes in Task 3)
- Modify: `lib/features/practice/presentation/screens/progress_screen.dart` (1 call site — permanent value)
- Modify: `test/features/practice/presentation/screens/practice_session_screen_test.dart` (1 call site)
- Create: `test/features/practice/domain/entities/exercise_result_test.dart`

**Interfaces produced (Task 2/3 consume these exact signatures):**
```dart
bool shouldUseFlashcard(VocabRecord word, bool aiAvailable, double aiRatio, double roll)
double drawSessionAiRatio(double roll) // roll ∈ [0,1) → result ∈ [0.20, 0.80)
```

- [ ] **Step 1: write the failing tests** — create `test/features/practice/domain/entities/exercise_result_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

VocabRecord _record({int sm2Repetitions = 1}) => VocabRecord(
      id: 'id1',
      headword: 'word',
      inputType: InputType.word,
      ipa: '',
      meaning: 'nghĩa',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sm2Repetitions: sm2Repetitions,
    );

void main() {
  group('shouldUseFlashcard', () {
    test('a never-reviewed word is always flashcard, any aiRatio/roll', () {
      expect(shouldUseFlashcard(_record(sm2Repetitions: 0), true, 1.0, 0.99),
          isTrue);
    });

    test('no AI available is always flashcard, any aiRatio/roll', () {
      expect(shouldUseFlashcard(_record(), false, 1.0, 0.99), isTrue);
    });

    test('aiRatio 0 is always flashcard for an eligible word', () {
      expect(shouldUseFlashcard(_record(), true, 0.0, 0.99), isTrue);
      expect(shouldUseFlashcard(_record(), true, 0.0, 0.0), isTrue);
    });

    test('aiRatio 1 is never flashcard for an eligible word', () {
      expect(shouldUseFlashcard(_record(), true, 1.0, 0.99), isFalse);
      expect(shouldUseFlashcard(_record(), true, 1.0, 0.0), isFalse);
    });

    test('reproduces the historical 30/70 split at aiRatio 0.7', () {
      // flashcardProb = 1 - 0.7 = 0.3
      expect(shouldUseFlashcard(_record(), true, 0.7, 0.2), isTrue); // < 0.3
      expect(shouldUseFlashcard(_record(), true, 0.7, 0.3), isFalse); // boundary: not flashcard
      expect(shouldUseFlashcard(_record(), true, 0.7, 0.5), isFalse);
    });
  });

  group('drawSessionAiRatio', () {
    test('roll 0 maps to the low end of the range', () {
      expect(drawSessionAiRatio(0.0), 0.20);
    });

    test('roll approaching 1 maps to the high end of the range', () {
      expect(drawSessionAiRatio(1.0), 0.80);
    });

    test('roll 0.5 maps to the midpoint', () {
      expect(drawSessionAiRatio(0.5), 0.50);
    });
  });
}
```
- [ ] **Step 2: run, confirm RED** — `flutter test test/features/practice/domain/entities/exercise_result_test.dart` fails (no `shouldUseFlashcard`/`drawSessionAiRatio`).
- [ ] **Step 3: implement** — in `lib/features/practice/domain/entities/exercise_result.dart`, change `SessionConfig` and add the two functions:
```dart
final class SessionConfig {
  const SessionConfig({required this.words, required this.aiRatio});
  final List<VocabRecord> words; // pre-shuffled by caller
  final double aiRatio; // 0.0–1.0; probability an eligible word gets an AI exercise
}

/// Decides flashcard vs AI for one word. `roll` is a single random value in
/// [0, 1) supplied by the caller (keeps this pure/testable — no RNG inside).
/// A never-reviewed word or no AI key always wins regardless of `aiRatio`;
/// otherwise the word is flashcard iff `roll` falls in the `(1 - aiRatio)`
/// slice. At `aiRatio == 0.7` this reproduces the historical 30/70 split.
bool shouldUseFlashcard(
  VocabRecord word,
  bool aiAvailable,
  double aiRatio,
  double roll,
) {
  if (word.sm2Repetitions == 0 || !aiAvailable) return true;
  return roll < (1 - aiRatio);
}

/// Maps a single random `roll` in [0, 1) to a session AI-mix ratio in
/// [0.20, 0.80] — used once per "Trộn AI" session, never per word.
double drawSessionAiRatio(double roll) => 0.20 + roll * 0.60;
```
- [ ] **Step 4: fix the 4 broken call sites** (SessionConfig now requires `aiRatio`):
  - `lib/features/practice/presentation/screens/practice_home_screen.dart` line ~116:
    `context.go('/practice/session', extra: SessionConfig(words: limited, aiRatio: 0));`
    (placeholder — Task 3 replaces `0` with the real computed value)
  - same file, line ~135 (`_startDueSession`):
    `context.go('/practice/session', extra: SessionConfig(words: shuffled, aiRatio: 0));`
    (placeholder — Task 3 replaces this one too)
  - `lib/features/practice/presentation/screens/progress_screen.dart` line ~223:
    `context.push('/practice/session', extra: SessionConfig(words: shuffled, aiRatio: 0.0));`
    (**permanent** — this quick-start has no toggle UI; leave as `0.0` forever, no further change in a later task)
  - `test/features/practice/presentation/screens/practice_session_screen_test.dart` line ~64:
    `home: PracticeSessionScreen(config: SessionConfig(words: [_record], aiRatio: 0)),`
- [ ] **Step 5: run, confirm GREEN** — `flutter test test/features/practice/domain/entities/exercise_result_test.dart` and `flutter test test/features/practice/presentation/screens/practice_session_screen_test.dart` both pass. `flutter analyze` → 0.
- [ ] **Step 6: commit** `feat(practice): SessionConfig.aiRatio + shouldUseFlashcard/drawSessionAiRatio pure functions`.

## Task 2: Flutter — wire `PracticeSessionNotifier` to `aiRatio`

**Files:**
- Modify: `lib/features/practice/presentation/providers/practice_session_provider.dart`
- Modify: `test/features/practice/presentation/screens/practice_session_screen_test.dart` (fix `_fakeState`)
- Create: `test/features/practice/presentation/providers/practice_session_provider_test.dart`

**Consumes:** `shouldUseFlashcard`/`drawSessionAiRatio` from Task 1 (already imported via the existing `import '../../domain/entities/exercise_result.dart';`).
**Produces:** `PracticeSessionState.aiRatio` (consumed nowhere else yet — Task 3's UI only reads/writes `SessionConfig.aiRatio`).

- [ ] **Step 1: write the failing tests** — create `test/features/practice/presentation/providers/practice_session_provider_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/practice/data/sources/exercise_generator_source.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/domain/use_cases/generate_exercise_use_case.dart';
import 'package:lexi_core/features/practice/presentation/providers/practice_session_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

class MockExerciseGeneratorSource extends Mock
    implements ExerciseGeneratorSource {}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

UserSettingsState _settings({required bool aiAvailable}) =>
    UserSettingsState.defaults.copyWith(providerConfigs: {
      AiProvider.gemini: ProviderConfig(
        apiKeyCiphertext: aiAvailable ? 'ck' : null,
        model: 'gemini-2.5-flash',
      ),
    });

VocabRecord _record({int sm2Repetitions = 1}) => VocabRecord(
      id: 'id1',
      headword: 'word',
      inputType: InputType.word,
      ipa: '',
      meaning: 'nghĩa',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sm2Repetitions: sm2Repetitions,
    );

ProviderContainer _container({
  required bool aiAvailable,
  required MockExerciseGeneratorSource source,
}) =>
    ProviderContainer(overrides: [
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(_settings(aiAvailable: aiAvailable)),
      ),
      generateExerciseUseCaseProvider
          .overrideWithValue(GenerateExerciseUseCase(source)),
    ]);

void main() {
  setUpAll(() => registerFallbackValue(_record()));

  test('aiRatio 0 never calls the AI source even when AI is available',
      () async {
    final source = MockExerciseGeneratorSource();
    final container = _container(aiAvailable: true, source: source);
    addTearDown(container.dispose);
    final notifier = container.read(practiceSessionNotifierProvider.notifier);

    await notifier.startSession(
      SessionConfig(words: [_record(sm2Repetitions: 3)], aiRatio: 0),
    );

    final state = container.read(practiceSessionNotifierProvider).value!;
    expect(state.aiRatio, 0);
    expect(state.exercises.single, isA<FlashcardExercise>());
    verifyNever(() => source.generate(any()));
  });

  test('aiRatio 1 calls the AI source for a reviewed word when AI is available',
      () async {
    final source = MockExerciseGeneratorSource();
    when(() => source.generate(any())).thenAnswer((_) async =>
        MultipleChoiceExercise(
          vocabRecord: _record(),
          question: 'q',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: 0,
        ));
    final container = _container(aiAvailable: true, source: source);
    addTearDown(container.dispose);
    final notifier = container.read(practiceSessionNotifierProvider.notifier);

    await notifier.startSession(
      SessionConfig(words: [_record(sm2Repetitions: 3)], aiRatio: 1),
    );

    final state = container.read(practiceSessionNotifierProvider).value!;
    expect(state.aiRatio, 1);
    expect(state.exercises.single, isA<MultipleChoiceExercise>());
    verify(() => source.generate(any())).called(1);
  });

  test('a never-reviewed word stays flashcard even at aiRatio 1', () async {
    final source = MockExerciseGeneratorSource();
    final container = _container(aiAvailable: true, source: source);
    addTearDown(container.dispose);
    final notifier = container.read(practiceSessionNotifierProvider.notifier);

    await notifier.startSession(
      SessionConfig(words: [_record(sm2Repetitions: 0)], aiRatio: 1),
    );

    final state = container.read(practiceSessionNotifierProvider).value!;
    expect(state.exercises.single, isA<FlashcardExercise>());
    verifyNever(() => source.generate(any()));
  });
}
```
- [ ] **Step 2: run, confirm RED** — fails (`PracticeSessionState` has no `aiRatio`).
- [ ] **Step 3: implement** — in `lib/features/practice/presentation/providers/practice_session_provider.dart`:
  - `PracticeSessionState` gains the field (constructor + `copyWith` pass-through + the `empty` const):
    ```dart
    final class PracticeSessionState {
      const PracticeSessionState({
        required this.words,
        required this.exercises,
        required this.currentIndex,
        required this.results,
        required this.isComplete,
        required this.aiRatio,
      });

      final List<VocabRecord> words;
      final List<Exercise?> exercises;
      final int currentIndex;
      final List<ExerciseResult> results;
      final bool isComplete;
      final double aiRatio; // fixed for the whole session, set once in startSession

      Exercise? get currentExercise =>
          currentIndex < exercises.length ? exercises[currentIndex] : null;

      bool get hasMore => currentIndex < words.length - 1;

      PracticeSessionState copyWith({
        List<VocabRecord>? words,
        List<Exercise?>? exercises,
        int? currentIndex,
        List<ExerciseResult>? results,
        bool? isComplete,
      }) =>
          PracticeSessionState(
            words: words ?? this.words,
            exercises: exercises ?? this.exercises,
            currentIndex: currentIndex ?? this.currentIndex,
            results: results ?? this.results,
            isComplete: isComplete ?? this.isComplete,
            aiRatio: aiRatio,
          );

      static const empty = PracticeSessionState(
        words: [],
        exercises: [],
        currentIndex: 0,
        results: [],
        isComplete: false,
        aiRatio: 0,
      );
    }
    ```
  - `startSession` passes `aiRatio: config.aiRatio` into the initial state:
    ```dart
    Future<void> startSession(SessionConfig config) async {
      final words = List<VocabRecord>.from(config.words);
      final exercises = List<Exercise?>.filled(words.length, null);
      state = AsyncValue.data(PracticeSessionState(
        words: words,
        exercises: exercises,
        currentIndex: 0,
        results: const [],
        isComplete: false,
        aiRatio: config.aiRatio,
      ));
      await _generateAt(0, words);
      _generateAt(1, words); // background, don't await
    }
    ```
  - `_generateAt` reads `aiRatio` from state and calls the new pure function directly, replacing `_pickExercise` entirely:
    ```dart
    Future<void> _generateAt(int index, List<VocabRecord> words) async {
      if (index >= words.length) return;
      final word = words[index];
      final aiAvailable = ref.read(userSettingsNotifierProvider).aiAvailable;
      final aiRatio = state.valueOrNull?.aiRatio ?? 0;
      final exercise = shouldUseFlashcard(word, aiAvailable, aiRatio, _random.nextDouble())
          ? FlashcardExercise(vocabRecord: word)
          : await ref.read(generateExerciseUseCaseProvider).execute(word);

      final current = state.valueOrNull;
      if (current == null) return;
      final updated = List<Exercise?>.from(current.exercises);
      updated[index] = exercise;
      state = AsyncValue.data(current.copyWith(exercises: updated));
    }
    ```
  - **Delete** the old `Future<Exercise> _pickExercise(VocabRecord word, bool aiAvailable) async { ... }` method entirely — it's fully replaced by the two lines above.
- [ ] **Step 4: fix `_fakeState`** in `test/features/practice/presentation/screens/practice_session_screen_test.dart` (~line 35): add `aiRatio: 0,` to the `PracticeSessionState(...)` literal.
- [ ] **Step 5: run, confirm GREEN** — `flutter test test/features/practice/presentation/providers/practice_session_provider_test.dart test/features/practice/presentation/screens/practice_session_screen_test.dart`. `flutter analyze` → 0.
- [ ] **Step 6: commit** `feat(practice): PracticeSessionNotifier uses aiRatio instead of the hardcoded 30/70 split`.

## Task 3: Flutter — mode toggle on `practice_home_screen.dart`

**Files:**
- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart`
- Modify: `test/features/practice/presentation/screens/practice_home_screen_test.dart`

**Consumes:** `SessionConfig(words:, aiRatio:)`, `drawSessionAiRatio(double roll)` (Task 1).

- [ ] **Step 1: write the failing tests** — add to `test/features/practice/presentation/screens/practice_home_screen_test.dart`. First, change `_FakeGetVocabListUseCase` to return one record instead of always `const []` (needed so "Bắt đầu luyện tập" actually navigates instead of hitting the empty-list snackbar) — replace its `execute` body:
```dart
class _FakeGetVocabListUseCase implements GetVocabListUseCase {
  @override
  Future<List<VocabRecord>> execute({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      [
        VocabRecord(
          id: 'w1',
          headword: 'word',
          inputType: InputType.word,
          ipa: '',
          meaning: 'nghĩa',
          examples: const [],
          personalNotes: '',
          topicIds: const [],
          targetLanguage: language,
          cefrLevel: CEFRLevel.b1,
          activeContext: AppContext.general,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
}
```
(add `import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';` and `import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';` to the test file's imports.)

Then change `_buildScreen`'s `/practice/session` route to capture the pushed `extra` and add the two new tests at the end of `main()`:
```dart
SessionConfig? capturedConfig;

Future<Widget> _buildScreen() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  capturedConfig = null;
  final router = GoRouter(
    initialLocation: '/practice/vocab',
    routes: [
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice hub')),
      ),
      GoRoute(
        path: '/practice/vocab',
        builder: (ctx, state) => const PracticeHomeScreen(),
      ),
      GoRoute(
        path: '/practice/session',
        builder: (ctx, state) {
          capturedConfig = state.extra as SessionConfig?;
          return const Scaffold(body: Text('Session screen'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(_FakeSettingsNotifier.new),
      topicsNotifierProvider.overrideWith(_FakeTopicsNotifier.new),
      getVocabListUseCaseProvider.overrideWithValue(_FakeGetVocabListUseCase()),
      statsServiceProvider.overrideWithValue(_FakeStatsService()),
    ],
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}
```
(`SessionConfig` import already added above.) New tests (the toggle's default is asserted BEHAVIORALLY — via the `aiRatio` it produces — rather than by introspecting the private `_PracticeMode` enum from the test file, which lives in a different library and can't be named there):
```dart
  testWidgets('renders both mode labels, Flashcard and Trộn AI', (tester) async {
    await tester.pumpWidget(await _buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Flashcard'), findsOneWidget);
    expect(find.text('Trộn AI'), findsOneWidget);
  });

  testWidgets(
      'starting without touching the toggle produces aiRatio 0 (Flashcard is the default)',
      (tester) async {
    await tester.pumpWidget(await _buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(BloomPillButton, 'Bắt đầu luyện tập'));
    await tester.pumpAndSettle();

    expect(capturedConfig!.aiRatio, 0);
    expect(find.text('Session screen'), findsOneWidget);
  });

  testWidgets(
      'tapping Trộn AI before starting produces an aiRatio in [0.20, 0.80]',
      (tester) async {
    await tester.pumpWidget(await _buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trộn AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BloomPillButton, 'Bắt đầu luyện tập'));
    await tester.pumpAndSettle();

    expect(capturedConfig!.aiRatio, greaterThanOrEqualTo(0.20));
    expect(capturedConfig!.aiRatio, lessThanOrEqualTo(0.80));
  });
```
- [ ] **Step 2: run, confirm RED**.
- [ ] **Step 3: implement** — in `lib/features/practice/presentation/screens/practice_home_screen.dart`:
  - Add `import 'dart:math';` to the imports.
  - Add near the top of the file (module level, above the widget class):
    ```dart
    enum _PracticeMode { flashcard, mixed }
    ```
  - Add a state field: `_PracticeMode _mode = _PracticeMode.flashcard;`
  - Add a helper method on the state class:
    ```dart
    double _resolveAiRatio() => _mode == _PracticeMode.flashcard
        ? 0.0
        : drawSessionAiRatio(Random().nextDouble());
    ```
  - `_start()`: change the `SessionConfig(words: limited, aiRatio: 0)` line to
    `SessionConfig(words: limited, aiRatio: _resolveAiRatio())`.
  - `_startDueSession()`: change `SessionConfig(words: shuffled, aiRatio: 0)` to
    `SessionConfig(words: shuffled, aiRatio: _resolveAiRatio())`.
  - In `build()`, insert after the "Số từ mỗi session" `FilterTile` and before `const Spacer()`:
    ```dart
    const SizedBox(height: 16),
    const BloomSectionHeader('Kiểu bài'),
    const SizedBox(height: 8),
    BloomSegmented<_PracticeMode>(
      segments: const [
        BloomSegment(value: _PracticeMode.flashcard, label: 'Flashcard'),
        BloomSegment(value: _PracticeMode.mixed, label: 'Trộn AI'),
      ],
      selected: _mode,
      onChanged: (m) => setState(() => _mode = m),
    ),
    ```
    (`BloomSectionHeader`/`BloomSegmented`/`BloomSegment` are already available via the existing `bloom.dart` barrel import.)
- [ ] **Step 4: run, confirm GREEN** — `flutter test test/features/practice/presentation/screens/practice_home_screen_test.dart`. `flutter analyze` → 0.
- [ ] **Step 5: commit** `feat(practice): Flashcard/Trộn AI mode toggle on the practice setup screen`.

## Task 4: Web — `pickExercise.ts` gains `aiRatio` + `drawSessionAiRatio`

**Files:**
- Modify: `apps/web/src/lib/pickExercise.ts`
- Modify: `apps/web/src/lib/pickExercise.test.ts`

- [ ] **Step 1: write the failing tests** — replace `apps/web/src/lib/pickExercise.test.ts` with:
```ts
import { describe, expect, it } from "vitest";
import { drawSessionAiRatio, shouldUseFlashcard } from "./pickExercise";

describe("shouldUseFlashcard", () => {
  it("returns true for a never-reviewed word even with AI available", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 0 }, true, 1, () => 0.99)).toBe(true);
  });

  it("returns true when no AI key is available", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 5 }, false, 1, () => 0.99)).toBe(true);
  });

  it("aiRatio 0 is always flashcard for an eligible word", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0, () => 0.99)).toBe(true);
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0, () => 0)).toBe(true);
  });

  it("aiRatio 1 is never flashcard for an eligible word", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 1, () => 0.99)).toBe(false);
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 1, () => 0)).toBe(false);
  });

  it("reproduces the historical 30/70 split at aiRatio 0.7", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0.7, () => 0.2)).toBe(true);
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0.7, () => 0.3)).toBe(false);
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0.7, () => 0.5)).toBe(false);
  });

  it("uses Math.random by default when rng is omitted", () => {
    // Just confirm it doesn't throw and returns a boolean when no rng is passed.
    expect(typeof shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0.5)).toBe("boolean");
  });
});

describe("drawSessionAiRatio", () => {
  it("roll 0 maps to the low end of the range", () => {
    expect(drawSessionAiRatio(() => 0)).toBeCloseTo(0.2);
  });

  it("roll approaching 1 maps to the high end of the range", () => {
    expect(drawSessionAiRatio(() => 0.999999)).toBeLessThanOrEqual(0.8);
    expect(drawSessionAiRatio(() => 0.999999)).toBeGreaterThan(0.79);
  });

  it("roll 0.5 maps to the midpoint", () => {
    expect(drawSessionAiRatio(() => 0.5)).toBeCloseTo(0.5);
  });

  it("uses Math.random by default and stays within [0.20, 0.80]", () => {
    const r = drawSessionAiRatio();
    expect(r).toBeGreaterThanOrEqual(0.2);
    expect(r).toBeLessThan(0.8);
  });
});
```
- [ ] **Step 2: run, confirm RED** — `npx vitest run pickExercise` (from `apps/web/`) fails.
- [ ] **Step 3: implement** — replace `apps/web/src/lib/pickExercise.ts` with:
```ts
import type { VocabRecord } from "./vocabRecords";

/**
 * Port of `shouldUseFlashcard`/`_pickExercise` in
 * `lib/features/practice/domain/entities/exercise_result.dart` (Flutter).
 *
 * `aiRatio` (0–1) is the probability an eligible word gets an AI-generated
 * exercise instead of a flashcard, for THIS session — drawn once via
 * `drawSessionAiRatio` when "Trộn AI" is chosen, or 0 for "Flashcard" mode.
 * A never-reviewed word (`sm2Repetitions === 0`) or a session with no AI key
 * always gets a flashcard regardless of `aiRatio`.
 */
export function shouldUseFlashcard(
  record: Pick<VocabRecord, "sm2Repetitions">,
  aiAvailable: boolean,
  aiRatio: number,
  rng: () => number = Math.random,
): boolean {
  if (record.sm2Repetitions === 0 || !aiAvailable) return true;
  // Written as `roll + aiRatio < 1` rather than `roll < 1 - aiRatio`: same
  // Flutter port (exercise_result.dart) hit a double-precision boundary bug
  // here — `1 - 0.7` is `0.30000000000000004`, not exactly `0.3` — which
  // misclassifies the `aiRatio == 1 - roll` boundary. `roll + aiRatio < 1`
  // avoids it (`0.3 + 0.7` rounds to exactly `1` in IEEE 754 double).
  return rng() + aiRatio < 1;
}

/**
 * Maps one random roll to a per-session AI-mix ratio in [0.20, 0.80) — drawn
 * ONCE when a "Trộn AI" session starts, never re-drawn mid-session or per word.
 */
export function drawSessionAiRatio(rng: () => number = Math.random): number {
  return 0.2 + rng() * 0.6;
}
```
- [ ] **Step 4: run, confirm GREEN** — `npx vitest run pickExercise` (from `apps/web/`). `npm run typecheck` clean.
- [ ] **Step 5: commit** `feat(web): pickExercise gains aiRatio + drawSessionAiRatio`.

## Task 5: Web — mode toggle + wiring on `practice/page.tsx`

**Files:**
- Modify: `apps/web/src/app/(app)/practice/page.tsx`
- Modify: `apps/web/src/app/(app)/practice/page.test.tsx`

**Consumes:** `shouldUseFlashcard(record, aiAvailable, aiRatio, rng?)`, `drawSessionAiRatio(rng?)` (Task 4).

- [ ] **Step 1: write the failing tests** — in `apps/web/src/app/(app)/practice/page.test.tsx`:
  1. Add `import { drawSessionAiRatio } from "@/lib/pickExercise";` is NOT needed (the page test asserts behavior, not the function directly).
  2. In the 3 existing tests inside `describe("PracticePage (AI exercise types)", ...)` that currently rely on the AI path firing — **"mixes in an AI multiple-choice exercise..."** (~line 427), **"falls back to a flashcard when generateExercise resolves to a flashcard..."** (~line 467), and **"drives a 3-word session through MC → fill-in-blank → translation..."** (~line 488) — insert a click on the new "Trộn AI" toggle button right after `render(<PracticePage />);` and before the `screen.findByRole("button", { name: "Bắt đầu" })` click:
     ```ts
     render(<PracticePage />);
     fireEvent.click(await screen.findByRole("button", { name: "Trộn AI" }));
     fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));
     ```
     (the 4th AI test, **"uses a flashcard with no AI call for a never-reviewed word..."** ~line 557, needs NO change — a never-reviewed word is flashcard regardless of mode.)
  3. Add two new tests at the end of the `"PracticePage (AI exercise types)"` describe block:
```ts
  it("the mode toggle defaults to Flashcard and never calls generateExercise for a reviewed word with a key set", async () => {
    mockSignedIn();
    mockSettingsWithKey();
    const record = makeRecord({ id: "1", headword: "steady", sm2Repetitions: 5 });
    vi.mocked(getVocabRecords).mockResolvedValue([record]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    expect(await screen.findByRole("button", { name: "Flashcard" })).toHaveClass("active");
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));

    await screen.findByTestId("flashcard-card");
    expect(generateExercise).not.toHaveBeenCalled();
  });

  it("switching to Trộn AI deselects Flashcard", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Trộn AI" }));
    expect(screen.getByRole("button", { name: "Trộn AI" })).toHaveClass("active");
    expect(screen.getByRole("button", { name: "Flashcard" })).not.toHaveClass("active");
  });
```
- [ ] **Step 2: run, confirm RED** — `npx vitest run practice` (from `apps/web/`) fails (no toggle rendered yet, updated AI tests fail because Flashcard-default now blocks the AI path).
- [ ] **Step 3: implement** — in `apps/web/src/app/(app)/practice/page.tsx`:
  - Add `import { generateExercise, type PracticeExercise } from "@/lib/practiceExercise";` (already present) and change the `pickExercise` import line to:
    `import { drawSessionAiRatio, shouldUseFlashcard } from "@/lib/pickExercise";`
  - Add state + ref, right after the existing `sessionTokenRef` declaration:
    ```ts
    const [practiceMode, setPracticeMode] = useState<"flashcard" | "mixed">("flashcard");
    const aiRatioRef = useRef(0);
    ```
  - In `generateAt`, change the flashcard check:
    `if (shouldUseFlashcard(word, aiAvailable, aiRatioRef.current)) {`
    (no other line in `generateAt` changes; `aiRatioRef` doesn't need to be in the `useCallback` dependency array, same convention as `exercisesRef`.)
  - In `handleStart`, right before/alongside `const token = ++sessionTokenRef.current;` add:
    `aiRatioRef.current = practiceMode === "flashcard" ? 0 : drawSessionAiRatio();`
  - In the `action === "start"` auto-start `useEffect`, add the identical line right alongside its own `const token = ++sessionTokenRef.current;`, and add `practiceMode` to that effect's dependency array (`[action, records, generateAt, practiceMode]`) — the auto-start effect only ever fires once (guarded by `autoStartTriggeredRef`), before the setup screen's toggle is interactive, so it always sees the initial "flashcard" default in practice; the dependency is added purely for lint correctness, not because the behavior depends on it.
  - In the `phase === "setup"` JSX, insert a toggle row right after the closing `</div>` of `.practice-filters` and before `<p className="practice-preview-count">`:
    ```tsx
    <div className="chip-row" role="group" aria-label="Kiểu bài">
      <button
        type="button"
        className={`vb-chip${practiceMode === "flashcard" ? " active" : ""}`}
        onClick={() => setPracticeMode("flashcard")}
      >
        Flashcard
      </button>
      <button
        type="button"
        className={`vb-chip${practiceMode === "mixed" ? " active" : ""}`}
        onClick={() => setPracticeMode("mixed")}
      >
        Trộn AI
      </button>
    </div>
    ```
    (`.chip-row` and `.vb-chip`/`.vb-chip.active` already exist in `apps/web/src/styles/bloom.css` — no CSS changes needed.)
- [ ] **Step 4: run, confirm GREEN** — `npx vitest run practice` (from `apps/web/`). `npm run typecheck` clean.
- [ ] **Step 5: commit** `feat(web): Flashcard/Trộn AI mode toggle on the Practice setup screen`.

## Task 6: full-suite gate + docs

- [ ] Flutter: `flutter analyze` → 0. `flutter test` → green, count only up from 909.
- [ ] Web (from `apps/web/`): `npm run typecheck` clean. `npx vitest run` → green, count only up from 795 (tolerate the 1 known pre-existing order/slow-machine-dependent flake in `vocab-bank`/`listening/dictation` tests if it surfaces — do not treat it as caused by this plan).
- [ ] `README.md` — in the "Luyện tập cách khoảng" section, add a line noting the session-level Flashcard/Trộn AI toggle (default Flashcard; Trộn AI picks a random 20–80% AI mix per session), on both platforms.
- [ ] Commit `docs: SM-2 practice mode toggle (Flashcard vs Trộn AI)`.

---

## Self-Review

- Spec coverage: two modes chosen at setup, not persisted → Tasks 3/5 (UI, default state, no persistence layer touched). Ratio randomized once per session in [0.20,0.80] → `drawSessionAiRatio` (Task 1/4), called exactly once per session start (Tasks 3/5). rep=0/no-key override unchanged → preserved verbatim in `shouldUseFlashcard`'s first line, both platforms. Both platforms → Tasks 1-3 (Flutter) + 4-5 (web). AI type selection/CEFR hints/SM-2 scoring untouched → no task touches `ExerciseGeneratorSource`/`generateExercise`/`computeSm2`/`buildExercisePrompt`.
- Placeholder scan: none — every step has literal code, exact file lines, and the two Flutter placeholder `aiRatio: 0` call sites are explicitly flagged as temporary (Task 1) vs permanent (`progress_screen.dart`).
- Type/signature consistency: `shouldUseFlashcard(word, aiAvailable, aiRatio, roll)` (Flutter, plain `double roll`) vs `shouldUseFlashcard(record, aiAvailable, aiRatio, rng?)` (web, function `rng` — matches its pre-existing convention) are deliberately shaped differently per platform idiom; both encode the identical `roll < 1 - aiRatio` formula. `drawSessionAiRatio` mirrors the same asymmetry (`double roll` vs `rng?`).
- Risk: Task 3/5's widget/page tests are the fiddliest (simulating a toggle click + asserting a captured navigation payload). Both tasks specify the exact harness change needed (route `extra` capture for Flutter, existing `toHaveClass` availability for web, confirmed via `vitest.setup.ts`'s `@testing-library/jest-dom/vitest` import) rather than leaving it to the implementer to invent.
- Risk: forgetting to update the 3 already-passing "AI exercise types" web tests (now blocked by the new Flashcard-default) is the single most likely regression — Task 5 Step 1 names the exact 3 tests and the exact 2 lines to insert in each.

## Execution Handoff

Subagent-driven. 6 tasks, sequential (each Flutter task builds on the previous; Task 4 is independent of Tasks 1-3 and could run in parallel, but the controller should keep the ledger simple and run 1→2→3→4→5→6 in order).
