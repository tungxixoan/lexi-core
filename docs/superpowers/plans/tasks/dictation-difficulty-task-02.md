# Nghe chép Difficulty Levels — Task 02: Extend DictationPracticeNotifier

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01 (`DictationDifficulty`, `BlankSpan`, `SelectDictationBlanksUseCase`)

## Global Constraints
(see `dictation-difficulty-global-constraints.md`)

## What This Task Delivers
Adds `difficulty`, `blanks`, `blankAnswers` to `DictationSessionState`/`DictationSessionResult`, a new `updateBlankAnswer()` notifier method, and blank-based scoring (`blockAccuracy`, `isBlankCorrect`) — **all additive with defaults that reproduce today's exact behavior**. `generate()` gains an optional `difficulty` parameter (default `DictationDifficulty.hard`) and now calls `SelectDictationBlanksUseCase` to populate `blanks`. Every existing call site, test, and screen keeps compiling and behaving identically without modification — this task's own tests are the only new ones added, plus one mechanical one-line fix to an unrelated test file's fake notifier so it still type-checks against the widened base signature (see Step 8).

## Files
- Modify: `lib/core/di/app_providers.dart`
- Modify: `lib/features/listening/presentation/providers/dictation_practice_provider.dart`
- Modify: `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
- Modify: `test/features/listening/presentation/screens/dictation_home_screen_test.dart` (mechanical fix only, see Step 8)

## Interfaces
- Consumes: `DictationDifficulty`, `BlankSpan`, `SelectDictationBlanksUseCase` from Task 01
- Produces:
  - `DictationSessionResult(..., difficulty = DictationDifficulty.hard, blanks = const [], blankAnswers = const [])` — adds `targetTextFor(BlankSpan)`, `isBlankCorrect(int index)`, `blockAccuracy` getters; `finalScore`/`sm2Quality` now read from `charAccuracy` (Khó) or `blockAccuracy` (Dễ/Trung bình) depending on `difficulty`
  - `DictationSessionState(..., difficulty = DictationDifficulty.hard, blanks = const [], blankAnswers = const [])` — adds `isClozeMode`, `allBlanksFilled` getters
  - `DictationPracticeNotifier.generate({..., DictationDifficulty difficulty = DictationDifficulty.hard})` — now also computes and stores `blanks`/`blankAnswers`
  - `DictationPracticeNotifier.updateBlankAnswer(int blankIndex, String text)`

## Steps

- [ ] **Step 1: Add the SelectDictationBlanksUseCase DI provider**

In `lib/core/di/app_providers.dart`, add this import after the existing `// --- Listening DI (Plan 9) ---` imports:

```dart
import '../../features/listening/domain/use_cases/select_dictation_blanks_use_case.dart';
```

Add this provider at the end of the file:

```dart
@riverpod
SelectDictationBlanksUseCase selectDictationBlanksUseCase(
        SelectDictationBlanksUseCaseRef ref) =>
    const SelectDictationBlanksUseCase();
```

Run codegen:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `app_providers.g.dart` regenerated with `selectDictationBlanksUseCaseProvider`.

- [ ] **Step 2: Write the failing tests for DictationSessionResult's blank-based scoring**

In `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`, add this import:

```dart
import 'package:lexi_core/features/listening/domain/entities/blank_span.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
```

Then add this new group immediately after the existing `group('DictationSessionResult scoring', ...)` block (i.e. right before `group('DictationPracticeNotifier lifecycle', ...)`):

```dart
  group('DictationSessionResult blank-based scoring (Dễ/Trung bình)', () {
    // "The quick brown fox jumps" — 5 words, indices 0-4.
    final easyItem = _item('The quick brown fox jumps');
    const easyBlanks = [
      BlankSpan(startWordIndex: 1, wordCount: 1), // "quick"
      BlankSpan(startWordIndex: 3, wordCount: 1), // "fox"
    ];

    test('blockAccuracy is 1.0 when blanks is empty (default/hard)', () {
      final result = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
      );
      expect(result.blockAccuracy, 1.0);
    });

    test('isBlankCorrect matches case-insensitively and trims whitespace', () {
      final result = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['  QUICK ', 'fox'],
      );
      expect(result.isBlankCorrect(0), isTrue);
      expect(result.isBlankCorrect(1), isTrue);
    });

    test('blockAccuracy counts correct blanks out of total', () {
      final result = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['quick', 'wrong'],
      );
      expect(result.isBlankCorrect(0), isTrue);
      expect(result.isBlankCorrect(1), isFalse);
      expect(result.blockAccuracy, 0.5);
    });

    test('finalScore uses blockAccuracy (not charAccuracy) when difficulty is not hard', () {
      final result = DictationSessionResult(
        item: easyItem,
        typed: 'completely different text that would score low on charAccuracy',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['quick', 'fox'], // both correct
      );
      expect(result.blockAccuracy, 1.0);
      expect(result.finalScore, 1.0); // ignores the garbage `typed` field entirely
    });

    test('finalScore still uses charAccuracy when difficulty is hard (default), '
        'even if blanks/blankAnswers happen to be set', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hello world.',
        replayCount: 0,
        duration: const Duration(seconds: 1),
      );
      expect(result.finalScore, 1.0); // via charAccuracy, unaffected by this task
    });

    test('sm2Quality maps blockAccuracy-derived finalScore using the same thresholds', () {
      final allCorrect = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['quick', 'fox'],
      );
      expect(allCorrect.sm2Quality, 5); // blockAccuracy 1.0

      final halfCorrect = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['quick', 'wrong'],
      );
      expect(halfCorrect.sm2Quality, 2); // blockAccuracy 0.5 >= 0.40
    });
  });
```

- [ ] **Step 3: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart
```

Expected: FAIL — `difficulty`/`blanks`/`blankAnswers` parameters and `blockAccuracy`/`isBlankCorrect`/`targetTextFor` don't exist yet on `DictationSessionResult`.

- [ ] **Step 4: Write the failing tests for the notifier's new behavior**

In the same test file, add this new group at the end of `main()`, after the existing `group('DictationPracticeNotifier lifecycle', ...)` block's closing brace (but still inside `void main() { ... }`):

```dart
  group('DictationPracticeNotifier difficulty/blanks', () {
    late MockGenerateDictationItemUseCase mockUseCase;
    late MockTtsService mockTts;
    late DictationItem fixedItem;
    late List<VocabRecord> words;

    setUp(() {
      mockUseCase = MockGenerateDictationItemUseCase();
      mockTts = MockTtsService();
      fixedItem = _item('The quick brown fox jumps over the lazy dog again');
      words = [
        VocabRecord(
          id: 'id1',
          headword: 'hello',
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
      ];
      when(
        () => mockUseCase.execute(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        ),
      ).thenAnswer((_) async => fixedItem);
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage))
          .thenAnswer((_) async {});
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            generateDictationItemUseCaseProvider.overrideWithValue(mockUseCase),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
        );

    test('generate() without difficulty defaults to hard with no blanks', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);

      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      );

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.difficulty, DictationDifficulty.hard);
      expect(state.blanks, isEmpty);
      expect(state.blankAnswers, isEmpty);
      expect(state.isClozeMode, isFalse);
    });

    test('generate() with difficulty: easy populates exactly 2 blanks and matching blankAnswers', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);

      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        difficulty: DictationDifficulty.easy,
      );

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.difficulty, DictationDifficulty.easy);
      expect(state.blanks.length, 2);
      expect(state.blankAnswers, ['', '']);
      expect(state.isClozeMode, isTrue);
    });

    test('updateBlankAnswer() updates only the targeted blank without completing', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        difficulty: DictationDifficulty.easy,
      );

      notifier.updateBlankAnswer(0, 'quick');

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.blankAnswers[0], 'quick');
      expect(state.blankAnswers[1], '');
      expect(state.isComplete, false);
    });

    test('allBlanksFilled is true only once every blank has non-empty text', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        difficulty: DictationDifficulty.easy,
      );

      expect(c.read(dictationPracticeNotifierProvider).value!.allBlanksFilled, isFalse);

      notifier.updateBlankAnswer(0, 'quick');
      expect(c.read(dictationPracticeNotifierProvider).value!.allBlanksFilled, isFalse);

      notifier.updateBlankAnswer(1, 'fox');
      expect(c.read(dictationPracticeNotifierProvider).value!.allBlanksFilled, isTrue);
    });
  });
```

- [ ] **Step 5: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart
```

Expected: FAIL — `generate()` doesn't accept `difficulty:`, `updateBlankAnswer` doesn't exist, `isClozeMode`/`allBlanksFilled` don't exist.

- [ ] **Step 6: Replace dictation_practice_provider.dart**

Replace `lib/features/listening/presentation/providers/dictation_practice_provider.dart` with:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/blank_span.dart';
import '../../domain/entities/dictation_difficulty.dart';
import '../../domain/entities/dictation_item.dart';

part 'dictation_practice_provider.g.dart';

final class DictationSessionResult {
  const DictationSessionResult({
    required this.item,
    required this.typed,
    required this.replayCount,
    required this.duration,
    this.difficulty = DictationDifficulty.hard,
    this.blanks = const [],
    this.blankAnswers = const [],
  });

  final DictationItem item;
  final String typed;
  final int replayCount;
  final Duration duration;
  final DictationDifficulty difficulty;
  final List<BlankSpan> blanks;
  final List<String> blankAnswers;

  int get totalChars => item.target.length;

  int get correctChars {
    int correct = 0;
    final limit = typed.length < item.target.length
        ? typed.length
        : item.target.length;
    for (int i = 0; i < limit; i++) {
      if (typed[i] == item.target[i]) correct++;
    }
    return correct;
  }

  double get charAccuracy => totalChars == 0 ? 1.0 : correctChars / totalChars;

  List<String> get _targetWords =>
      item.target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// The correct text for [blank] — one or more words joined by a single space.
  String targetTextFor(BlankSpan blank) => _targetWords
      .skip(blank.startWordIndex)
      .take(blank.wordCount)
      .join(' ');

  String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool isBlankCorrect(int index) =>
      _normalize(blankAnswers[index]) == _normalize(targetTextFor(blanks[index]));

  double get blockAccuracy {
    if (blanks.isEmpty) return 1.0;
    final correctCount =
        List.generate(blanks.length, (i) => i).where(isBlankCorrect).length;
    return correctCount / blanks.length;
  }

  double get _rawAccuracy =>
      difficulty == DictationDifficulty.hard ? charAccuracy : blockAccuracy;

  double get finalScore => (_rawAccuracy - 0.05 * replayCount).clamp(0.0, 1.0);

  int get sm2Quality {
    final score = finalScore;
    if (score >= 0.95) return 5;
    if (score >= 0.80) return 4;
    if (score >= 0.60) return 3;
    if (score >= 0.40) return 2;
    return 0;
  }
}

final class DictationSessionState {
  const DictationSessionState({
    required this.item,
    required this.typedText,
    required this.replayCount,
    required this.hasPlayedOnce,
    required this.startedAt,
    required this.isComplete,
    this.difficulty = DictationDifficulty.hard,
    this.blanks = const [],
    this.blankAnswers = const [],
  });

  final DictationItem item;
  final String typedText;
  final int replayCount;
  final bool hasPlayedOnce;
  final DateTime startedAt;
  final bool isComplete;
  final DictationDifficulty difficulty;
  final List<BlankSpan> blanks;
  final List<String> blankAnswers;

  bool get isClozeMode => difficulty != DictationDifficulty.hard;

  bool get allBlanksFilled =>
      blankAnswers.isNotEmpty && blankAnswers.every((a) => a.trim().isNotEmpty);

  DictationSessionState copyWith({
    String? typedText,
    int? replayCount,
    bool? hasPlayedOnce,
    bool? isComplete,
    List<String>? blankAnswers,
  }) =>
      DictationSessionState(
        item: item,
        typedText: typedText ?? this.typedText,
        replayCount: replayCount ?? this.replayCount,
        hasPlayedOnce: hasPlayedOnce ?? this.hasPlayedOnce,
        startedAt: startedAt,
        isComplete: isComplete ?? this.isComplete,
        difficulty: difficulty,
        blanks: blanks,
        blankAnswers: blankAnswers ?? this.blankAnswers,
      );
}

@riverpod
class DictationPracticeNotifier extends _$DictationPracticeNotifier {
  @override
  AsyncValue<DictationSessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
    DictationDifficulty difficulty = DictationDifficulty.hard,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final item = await ref.read(generateDictationItemUseCaseProvider).execute(
            words: words,
            level: level,
            context: context,
            targetLanguage: targetLanguage,
          );
      final blanks = ref
          .read(selectDictationBlanksUseCaseProvider)
          .execute(item.target, difficulty);
      return DictationSessionState(
        item: item,
        typedText: '',
        replayCount: 0,
        hasPlayedOnce: false,
        startedAt: DateTime.now(),
        isComplete: false,
        difficulty: difficulty,
        blanks: blanks,
        blankAnswers: List.filled(blanks.length, ''),
      );
    });
  }

  Future<void> play() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.hasPlayedOnce
          ? current.copyWith(replayCount: current.replayCount + 1)
          : current.copyWith(hasPlayedOnce: true),
    );
    await ref
        .read(ttsServiceProvider)
        .speak(current.item.target, current.item.targetLanguage);
  }

  void updateTypedText(String text) {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    state = AsyncData(current.copyWith(typedText: text));
  }

  void updateBlankAnswer(int blankIndex, String text) {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    final updated = List<String>.from(current.blankAnswers);
    updated[blankIndex] = text;
    state = AsyncData(current.copyWith(blankAnswers: updated));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    state = AsyncData(current.copyWith(isComplete: true));
  }

  void reset() => state = const AsyncData(null);
}
```

- [ ] **Step 7: Run test to confirm it passes**

```bash
flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart
```

Expected: all tests pass — the original scoring/lifecycle groups (unmodified) plus the two new groups added in Steps 2 and 4.

- [ ] **Step 8: Fix the one call site that must widen to match — `_FakeDictationNotifier` in dictation_home_screen_test.dart**

`generate()`'s base signature now has an extra optional named parameter (`difficulty`). Dart requires an `@override` to accept every parameter the overridden method declares, so the hand-written override in `test/features/listening/presentation/screens/dictation_home_screen_test.dart` must add it too — this is a mechanical signature fix, not a change to that test file's actual assertions or behavior.

Find this exact block in that file:

```dart
class _FakeDictationNotifier extends DictationPracticeNotifier {
  List<VocabRecord>? capturedWords;
  int callCount = 0;

  @override
  AsyncValue<DictationSessionState?> build() => const AsyncData(null);

  @override
  Future<void> generate({
    required List<VocabRecord> words,
    required AppContext context,
    required Language targetLanguage,
    required CEFRLevel level,
  }) async {
    callCount++;
    capturedWords = words;
    // Leave state as AsyncData(null): the screen only navigates away when
    // the resulting session is non-null, so tests can stay on this screen.
  }
}
```

Replace it with:

```dart
class _FakeDictationNotifier extends DictationPracticeNotifier {
  List<VocabRecord>? capturedWords;
  int callCount = 0;

  @override
  AsyncValue<DictationSessionState?> build() => const AsyncData(null);

  @override
  Future<void> generate({
    required List<VocabRecord> words,
    required AppContext context,
    required Language targetLanguage,
    required CEFRLevel level,
    DictationDifficulty difficulty = DictationDifficulty.hard,
  }) async {
    callCount++;
    capturedWords = words;
    // Leave state as AsyncData(null): the screen only navigates away when
    // the resulting session is non-null, so tests can stay on this screen.
  }
}
```

Add this import to the top of the file (alongside the other `lexi_core` imports):

```dart
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
```

- [ ] **Step 9: Run the full test suite**

```bash
flutter test
```

Expected: all tests pass — every existing test (Dictation, Reading, everything else) is unaffected; only the new tests from Steps 2 and 4 are additions.

- [ ] **Step 10: Analyze**

```bash
flutter analyze lib/features/listening/ lib/core/di/app_providers.dart test/features/listening/
```

Expected: no issues.

- [ ] **Step 11: Verify Khó's existing behavior is byte-identical**

This is the task's most important guarantee — confirm it explicitly:

```bash
flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart --plain-name "DictationSessionResult scoring"
flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart --plain-name "DictationPracticeNotifier lifecycle"
```

Expected: both groups (the pre-existing ones, untouched by this task) still pass exactly as before.

- [ ] **Step 12: Commit**

```bash
git add lib/core/di/app_providers.dart \
        lib/core/di/app_providers.g.dart \
        lib/features/listening/presentation/providers/dictation_practice_provider.dart \
        test/features/listening/presentation/providers/dictation_practice_provider_test.dart \
        test/features/listening/presentation/screens/dictation_home_screen_test.dart
git commit -m "feat(dictation-difficulty): extend DictationPracticeNotifier with difficulty/blanks (additive, Khó unchanged)"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
