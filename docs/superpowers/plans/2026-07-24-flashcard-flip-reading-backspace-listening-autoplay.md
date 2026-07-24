# Flashcard Flip-Back, Reading Backspace Penalty, Listening Auto-Continue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let flashcards flip freely between front/back before grading, add a backspace-penalized `finalScore` to reading practice, and make listening comprehension auto-advance to the next turn after each one finishes naturally.

**Architecture:** Three independent, unrelated changes to existing widgets/providers — no new files besides tests. Each task is a self-contained vertical slice (state/logic change + its own test coverage) that can be implemented, reviewed, and merged separately.

**Tech Stack:** Flutter, Riverpod (`@riverpod` code-gen notifiers), `flutter_test`, `mocktail`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-24-flashcard-flip-reading-backspace-listening-autoplay-design.md`
- No new providers, no `build_runner` codegen needed — only method bodies and data-class fields change on existing `@riverpod` classes.
- Flashcard flip-back must not touch `ExerciseResult`/grading logic — grading only happens via the two buttons.
- Reading `finalScore` penalty: `0.01` (1%) per backspace event, `clamp(0.0, 1.0)`.
- Listening auto-continue must rely on the existing `playToken` supersede check — no new flag.
- Run tests with `flutter test <path>`.

---

### Task 1: Flashcard two-way flip

**Files:**
- Modify: `lib/features/practice/presentation/widgets/flashcard_widget.dart`
- Test: Create `test/features/practice/presentation/widgets/flashcard_widget_test.dart`

**Interfaces:**
- Consumes: `FlashcardExercise` (`lib/features/practice/domain/entities/exercise.dart`), `ExerciseResult` (`lib/features/practice/domain/entities/exercise_result.dart`), `VocabRecord` (`lib/features/vocabulary/domain/entities/vocab_record.dart`).
- Produces: `FlashcardWidget({required FlashcardExercise exercise, required void Function(ExerciseResult) onResult})` — public constructor signature is unchanged; only internal `_FlashcardWidgetState`/`_BackContent` behavior changes.

- [ ] **Step 1: Write the failing test file**

Create `test/features/practice/presentation/widgets/flashcard_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/presentation/widgets/flashcard_widget.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

final _record = VocabRecord(
  id: 'id1',
  headword: 'ephemeral',
  inputType: InputType.word,
  ipa: '/ɪˈfem(ə)rəl/',
  meaning: 'tồn tại trong thời gian ngắn',
  examples: const ['Fashions are ephemeral.'],
  personalNotes: '',
  topicIds: const [],
  targetLanguage: Language.english,
  cefrLevel: CEFRLevel.b1,
  activeContext: AppContext.general,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget _buildCard(void Function(ExerciseResult) onResult) => MaterialApp(
      home: Scaffold(
        body: FlashcardWidget(
          exercise: FlashcardExercise(vocabRecord: _record),
          onResult: onResult,
        ),
      ),
    );

void main() {
  testWidgets('starts showing the front (headword), not the meaning', (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    expect(find.text('ephemeral'), findsOneWidget);
    expect(find.text('tồn tại trong thời gian ngắn'), findsNothing);
  });

  testWidgets('tapping the front flips to the back (meaning)', (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();
    expect(find.text('tồn tại trong thời gian ngắn'), findsOneWidget);
    expect(find.text('ephemeral'), findsNothing);
  });

  testWidgets('tapping the meaning area on the back flips back to the front', (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('tồn tại trong thời gian ngắn'));
    await tester.pumpAndSettle();

    expect(find.text('ephemeral'), findsOneWidget);
    expect(find.text('tồn tại trong thời gian ngắn'), findsNothing);
  });

  testWidgets('can flip back and forth multiple times before grading', (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('ephemeral'));
      await tester.pumpAndSettle();
      expect(find.text('tồn tại trong thời gian ngắn'), findsOneWidget);

      await tester.tap(find.text('tồn tại trong thời gian ngắn'));
      await tester.pumpAndSettle();
      expect(find.text('ephemeral'), findsOneWidget);
    }
  });

  testWidgets('tapping mid-animation is ignored until the current flip settles', (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    await tester.tap(find.text('ephemeral'));
    await tester.pump(const Duration(milliseconds: 50)); // still animating forward
    await tester.tap(find.text('ephemeral')); // guarded no-op, must not reverse mid-flight
    await tester.pumpAndSettle();
    expect(find.text('tồn tại trong thời gian ngắn'), findsOneWidget);
  });

  testWidgets('Đã hiểu button reports understood=true', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_buildCard((r) => result = r));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isCorrect, isTrue);
    expect(result!.quality, 5);
  });

  testWidgets('Chưa hiểu button reports understood=false', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_buildCard((r) => result = r));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chưa hiểu'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isCorrect, isFalse);
    expect(result!.quality, 1);
  });

  testWidgets('grading buttons still work after flipping back and forth', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_buildCard((r) => result = r));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tồn tại trong thời gian ngắn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isCorrect, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify the flip-back tests fail**

Run: `flutter test test/features/practice/presentation/widgets/flashcard_widget_test.dart`
Expected: FAIL — "tapping the meaning area on the back flips back to the front", "can flip back and forth multiple times before grading", "tapping mid-animation is ignored...", and "grading buttons still work after flipping back and forth" all fail (today the back face has no tap handler at all, so the card never returns to the front). The other tests (initial front, front→back flip, Đã hiểu/Chưa hiểu results) already pass — that's expected, they cover existing behavior.

- [ ] **Step 3: Implement two-way flip in `flashcard_widget.dart`**

Replace the whole file content with:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

class FlashcardWidget extends StatefulWidget {
  const FlashcardWidget({super.key, required this.exercise, required this.onResult});
  final FlashcardExercise exercise;
  final void Function(ExerciseResult) onResult;

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _flipAnim =
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut);

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_flipCtrl.isAnimating) return;
    if (_flipCtrl.value == 0) {
      _flipCtrl.forward();
    } else {
      _flipCtrl.reverse();
    }
  }

  void _submit(bool understood) {
    widget.onResult(ExerciseResult(
      vocabRecordId: widget.exercise.vocabRecord.id,
      quality: understood ? 5 : 1,
      isCorrect: understood,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.exercise.vocabRecord;

    return AnimatedBuilder(
      animation: _flipAnim,
      builder: (context, _) {
        final angle = _flipAnim.value * math.pi;
        final showingBack = angle > math.pi / 2;
        final displayAngle = showingBack ? angle - math.pi : angle;

        final face = _CardFace(
          child: showingBack
              ? _BackContent(record: record, onSubmit: _submit, onTapToFlip: _toggleFlip)
              : _FrontContent(record: record),
        );

        final transformed = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(displayAngle),
          child: face,
        );

        // Front: whole card is tappable to flip. Back: only _BackContent's
        // own gesture detector (around the meaning/example area, excluding
        // the two grading buttons) triggers a flip back — an ancestor
        // GestureDetector here would compete with the buttons' tap
        // recognizers in the gesture arena.
        return showingBack
            ? transformed
            : GestureDetector(onTap: _toggleFlip, child: transformed);
      },
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 240),
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

class _FrontContent extends StatelessWidget {
  const _FrontContent({required this.record});
  final VocabRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(record.headword,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        if (record.ipa.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(record.ipa,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic, color: theme.colorScheme.secondary)),
        ],
        const SizedBox(height: 24),
        Icon(Icons.touch_app_outlined, color: theme.colorScheme.outline, size: 20),
        const SizedBox(height: 4),
        Text('Chạm vào thẻ để xem đáp án',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}

class _BackContent extends StatelessWidget {
  const _BackContent({
    required this.record,
    required this.onSubmit,
    required this.onTapToFlip,
  });
  final VocabRecord record;
  final void Function(bool understood) onSubmit;
  final VoidCallback onTapToFlip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapToFlip,
          child: Column(
            children: [
              Text(record.meaning, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              if (record.examples.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('"${record.examples.first}"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              Icon(Icons.flip_camera_android_outlined, color: theme.colorScheme.outline, size: 18),
              const SizedBox(height: 4),
              Text('Chạm để xem lại từ vựng',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onSubmit(false),
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                child: const Text('Chưa hiểu'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => onSubmit(true),
                child: const Text('Đã hiểu'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they all pass**

Run: `flutter test test/features/practice/presentation/widgets/flashcard_widget_test.dart`
Expected: PASS — all 8 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/practice/presentation/widgets/flashcard_widget.dart test/features/practice/presentation/widgets/flashcard_widget_test.dart
git commit -m "feat(practice): allow flipping flashcard back to front before grading"
```

---

### Task 2: Reading — backspace tracking and `finalScore`

**Files:**
- Modify: `lib/features/reading/presentation/providers/reading_practice_provider.dart`
- Test: Create `test/features/reading/presentation/providers/reading_practice_provider_test.dart`

**Interfaces:**
- Consumes: `ReadingPassage`, `BilingualSentence` (`lib/features/reading/domain/entities/reading_passage.dart`).
- Produces: `SentenceResult.backspaceCount` (int, default 0), `ReadingSessionResult.totalBackspaceCount` (int getter), `ReadingSessionResult.finalScore` (double getter), `ReadingSessionState.currentBackspaceCount` (int, default 0). All existing public members (`overallAccuracy`, `wpm`, `updateTypedText`, `reset`, etc.) keep their current signatures.

- [ ] **Step 1: Write the failing test file**

Create `test/features/reading/presentation/providers/reading_practice_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_reading_passage_use_case.dart';
import 'package:lexi_core/features/reading/presentation/providers/reading_practice_provider.dart';

class MockGenerateReadingPassageUseCase extends Mock
    implements GenerateReadingPassageUseCase {}

void main() {
  group('SentenceResult/ReadingSessionResult scoring', () {
    test('backspaceCount defaults to 0', () {
      const result = SentenceResult(
        target: 'Hello world.',
        typed: 'Hello world.',
        correctChars: 12,
        totalChars: 12,
        durationMs: 5000,
      );
      expect(result.backspaceCount, 0);
    });

    test('totalBackspaceCount sums backspaceCount across all sentences', () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [
            BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: []),
            BilingualSentence(target: 'B.', vietnamese: 'B.', vocabIds: []),
          ],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
            target: 'A.', typed: 'A.', correctChars: 2, totalChars: 2,
            durationMs: 1000, backspaceCount: 3,
          ),
          SentenceResult(
            target: 'B.', typed: 'B.', correctChars: 2, totalChars: 2,
            durationMs: 1000, backspaceCount: 2,
          ),
        ],
        totalDuration: const Duration(seconds: 2),
      );
      expect(result.totalBackspaceCount, 5);
    });

    test('finalScore equals overallAccuracy when there are no backspaces', () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: [])],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(target: 'A.', typed: 'A.', correctChars: 2, totalChars: 2, durationMs: 1000),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.overallAccuracy, 1.0);
      expect(result.finalScore, 1.0);
    });

    test('finalScore subtracts 1% per backspace from overallAccuracy', () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: [])],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
            target: 'A.', typed: 'A.', correctChars: 2, totalChars: 2,
            durationMs: 1000, backspaceCount: 10,
          ),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.overallAccuracy, 1.0);
      expect(result.finalScore, closeTo(0.90, 0.0001)); // 1.0 - 10*0.01
    });

    test('finalScore never goes below 0', () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: [])],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
            target: 'A.', typed: 'A.', correctChars: 0, totalChars: 2,
            durationMs: 1000, backspaceCount: 200,
          ),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.finalScore, 0.0);
    });
  });

  group('ReadingPracticeNotifier backspace tracking', () {
    late MockGenerateReadingPassageUseCase mockUseCase;
    late List<VocabRecord> words;
    late ReadingPassage fixedPassage;

    setUpAll(() {
      registerFallbackValue(CEFRLevel.a1);
      registerFallbackValue(AppContext.general);
      registerFallbackValue(Language.english);
    });

    setUp(() {
      mockUseCase = MockGenerateReadingPassageUseCase();
      fixedPassage = ReadingPassage(
        id: 'p1',
        sentences: const [
          BilingualSentence(target: 'Hi.', vietnamese: 'Chào.', vocabIds: []),
          BilingualSentence(target: 'Bye.', vietnamese: 'Tạm biệt.', vocabIds: []),
        ],
        vocabIds: const [],
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        generatedAt: DateTime(2026),
      );
      words = const [];
      when(
        () => mockUseCase.execute(
          words: any(named: 'words'),
          level: any(named: 'level'),
          context: any(named: 'context'),
          targetLanguage: any(named: 'targetLanguage'),
        ),
      ).thenAnswer((_) async => fixedPassage);
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            generateReadingPassageUseCaseProvider.overrideWithValue(mockUseCase),
          ],
        );

    Future<void> generateSession(ReadingPracticeNotifier notifier) => notifier.generate(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        );

    test('typing without deleting does not increment currentBackspaceCount', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('H');
      notifier.updateTypedText('Hi');

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentBackspaceCount, 0);
    });

    test('deleting a character increments currentBackspaceCount by 1 per deletion', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hix'); // typo
      notifier.updateTypedText('Hi'); // backspace 1
      notifier.updateTypedText('H'); // backspace 2

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentBackspaceCount, 2);
    });

    test('completing a sentence records its backspaceCount and resets the counter for the next one',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hix');
      notifier.updateTypedText('Hi.'); // backspace then retype to match target exactly

      var state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.completedSentences.length, 1);
      expect(state.completedSentences.first.backspaceCount, 1);
      expect(state.currentBackspaceCount, 0); // reset for sentence 2
      expect(state.currentSentenceIndex, 1);

      notifier.updateTypedText('Byex');
      notifier.updateTypedText('Bye');
      notifier.updateTypedText('Bye.');

      state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.completedSentences.length, 2);
      expect(state.completedSentences.last.backspaceCount, 2);
      expect(state.isComplete, true);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/reading/presentation/providers/reading_practice_provider_test.dart`
Expected: FAIL with compile errors — `backspaceCount`, `totalBackspaceCount`, `finalScore`, and `currentBackspaceCount` don't exist yet.

- [ ] **Step 3: Implement backspace tracking and `finalScore`**

Edit `lib/features/reading/presentation/providers/reading_practice_provider.dart`. Replace the `SentenceResult` class:

```dart
final class SentenceResult {
  const SentenceResult({
    required this.target,
    required this.typed,
    required this.correctChars,
    required this.totalChars,
    required this.durationMs,
    this.backspaceCount = 0,
  });

  final String target;
  final String typed;
  final int correctChars;
  final int totalChars;
  final int durationMs;
  final int backspaceCount;

  double get accuracy => totalChars == 0 ? 1.0 : correctChars / totalChars;
}
```

Replace the `ReadingSessionResult` class:

```dart
final class ReadingSessionResult {
  const ReadingSessionResult({
    required this.passage,
    required this.sentenceResults,
    required this.totalDuration,
  });

  final ReadingPassage passage;
  final List<SentenceResult> sentenceResults;
  final Duration totalDuration;

  double get overallAccuracy {
    if (sentenceResults.isEmpty) return 1.0;
    final totalCorrect =
        sentenceResults.fold(0, (s, r) => s + r.correctChars);
    final totalChars = sentenceResults.fold(0, (s, r) => s + r.totalChars);
    return totalChars == 0 ? 1.0 : totalCorrect / totalChars;
  }

  double get wpm {
    final totalTyped =
        sentenceResults.fold(0, (s, r) => s + r.typed.length);
    final minutes = totalDuration.inSeconds / 60.0;
    if (minutes == 0) return 0;
    return (totalTyped / 5.0) / minutes;
  }

  int get totalBackspaceCount =>
      sentenceResults.fold(0, (s, r) => s + r.backspaceCount);

  double get finalScore =>
      (overallAccuracy - 0.01 * totalBackspaceCount).clamp(0.0, 1.0);
}
```

Replace the `ReadingSessionState` class:

```dart
final class ReadingSessionState {
  const ReadingSessionState({
    required this.passage,
    required this.currentSentenceIndex,
    required this.typedText,
    required this.completedSentences,
    required this.sessionStartedAt,
    required this.sentenceStartedAt,
    required this.isComplete,
    this.currentBackspaceCount = 0,
  });

  final ReadingPassage passage;
  final int currentSentenceIndex;
  final String typedText;
  final List<SentenceResult> completedSentences;
  final DateTime sessionStartedAt;
  final DateTime sentenceStartedAt;
  final bool isComplete;
  final int currentBackspaceCount;

  BilingualSentence get currentSentence =>
      passage.sentences[currentSentenceIndex];

  ReadingSessionState copyWith({
    int? currentSentenceIndex,
    String? typedText,
    List<SentenceResult>? completedSentences,
    DateTime? sentenceStartedAt,
    bool? isComplete,
    int? currentBackspaceCount,
  }) =>
      ReadingSessionState(
        passage: passage,
        currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
        typedText: typedText ?? this.typedText,
        completedSentences: completedSentences ?? this.completedSentences,
        sessionStartedAt: sessionStartedAt,
        sentenceStartedAt: sentenceStartedAt ?? this.sentenceStartedAt,
        isComplete: isComplete ?? this.isComplete,
        currentBackspaceCount: currentBackspaceCount ?? this.currentBackspaceCount,
      );
}
```

Replace `updateTypedText` and `_advance` inside `ReadingPracticeNotifier`:

```dart
  void updateTypedText(String text) {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    final backspaceCount = text.length < current.typedText.length
        ? current.currentBackspaceCount + 1
        : current.currentBackspaceCount;
    if (text == current.currentSentence.target) {
      _advance(current.copyWith(currentBackspaceCount: backspaceCount), text);
    } else {
      state = AsyncData(current.copyWith(
        typedText: text,
        currentBackspaceCount: backspaceCount,
      ));
    }
  }

  void _advance(ReadingSessionState current, String typed) {
    final target = current.currentSentence.target;
    int correctChars = 0;
    for (int i = 0; i < typed.length && i < target.length; i++) {
      if (typed[i] == target[i]) correctChars++;
    }
    final result = SentenceResult(
      target: target,
      typed: typed,
      correctChars: correctChars,
      totalChars: target.length,
      durationMs: DateTime.now()
          .difference(current.sentenceStartedAt)
          .inMilliseconds,
      backspaceCount: current.currentBackspaceCount,
    );
    final nextIndex = current.currentSentenceIndex + 1;
    final isComplete = nextIndex >= current.passage.sentences.length;
    final now = DateTime.now();
    state = AsyncData(current.copyWith(
      currentSentenceIndex: nextIndex,
      typedText: '',
      completedSentences: [...current.completedSentences, result],
      sentenceStartedAt: now,
      isComplete: isComplete,
      currentBackspaceCount: 0,
    ));
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reading/presentation/providers/reading_practice_provider_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Run the full reading test suite to check for regressions**

Run: `flutter test test/features/reading/`
Expected: PASS — `reading_result_screen_test.dart` and `reading_session_screen_test.dart` still pass unchanged (both rely on the new fields' defaults of 0).

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/presentation/providers/reading_practice_provider.dart test/features/reading/presentation/providers/reading_practice_provider_test.dart
git commit -m "feat(reading): track backspaces and subtract them from a new finalScore"
```

---

### Task 3: Reading result screen — show the new score

**Files:**
- Modify: `lib/features/reading/presentation/screens/reading_result_screen.dart`
- Modify: `test/features/reading/presentation/screens/reading_result_screen_test.dart`

**Interfaces:**
- Consumes: `ReadingSessionResult.finalScore` (double getter, produced by Task 2).
- Produces: no new public API — purely a UI addition (4th `_StatCard`).

- [ ] **Step 1: Write the failing test**

In `test/features/reading/presentation/screens/reading_result_screen_test.dart`, add a fixture with backspaces and a test for the new stat card. Insert after the existing `_testResult` declaration (around line 39):

```dart
final _testResultWithBackspaces = ReadingSessionResult(
  passage: ReadingPassage(
    id: 'p2',
    sentences: const [
      BilingualSentence(
        target: 'Hello world.',
        vietnamese: 'Xin chào thế giới.',
        vocabIds: [],
      ),
    ],
    vocabIds: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  ),
  sentenceResults: const [
    SentenceResult(
      target: 'Hello world.',
      typed: 'Hello world.',
      correctChars: 12,
      totalChars: 12,
      durationMs: 5000,
      backspaceCount: 10,
    ),
  ],
  totalDuration: const Duration(seconds: 5),
);

Widget _buildResultWithBackspaces() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ReadingResultScreen(result: _testResultWithBackspaces),
      ),
      GoRoute(
        path: '/reading',
        builder: (ctx, state) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      vocabBankProvider.overrideWith((_) => const []),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
```

Then add to the `main()` block, after the existing two `testWidgets`:

```dart
  testWidgets('shows a score stat card labeled Điểm', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Điểm'), findsOneWidget);
  });

  testWidgets('score reflects the backspace penalty subtracted from accuracy', (tester) async {
    await tester.pumpWidget(_buildResultWithBackspaces());
    await tester.pumpAndSettle();
    // accuracy 100% - 10 backspaces * 1% = 90.0%
    expect(find.text('90.0%'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/reading/presentation/screens/reading_result_screen_test.dart`
Expected: FAIL — no widget with text `'Điểm'` exists yet, and `'90.0%'` isn't rendered.

- [ ] **Step 3: Add the score stat card**

In `lib/features/reading/presentation/screens/reading_result_screen.dart`, update the `build` method. Change:

```dart
    final accuracyPct = (result.overallAccuracy * 100).toStringAsFixed(1);
    final wpm = result.wpm.toStringAsFixed(0);
    final elapsed = _formatDuration(result.totalDuration);
```

to:

```dart
    final accuracyPct = (result.overallAccuracy * 100).toStringAsFixed(1);
    final wpm = result.wpm.toStringAsFixed(0);
    final elapsed = _formatDuration(result.totalDuration);
    final scorePct = (result.finalScore * 100).toStringAsFixed(1);
```

And change the stats `Row`:

```dart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Độ chính xác', value: '$accuracyPct%'),
                _StatCard(label: 'Tốc độ', value: '$wpm WPM'),
                _StatCard(label: 'Thời gian', value: elapsed),
              ],
            ),
```

to:

```dart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Độ chính xác', value: '$accuracyPct%'),
                _StatCard(label: 'Tốc độ', value: '$wpm WPM'),
                _StatCard(label: 'Thời gian', value: elapsed),
                _StatCard(label: 'Điểm', value: '$scorePct%'),
              ],
            ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reading/presentation/screens/reading_result_screen_test.dart`
Expected: PASS — all tests green, including the two new ones.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reading/presentation/screens/reading_result_screen.dart test/features/reading/presentation/screens/reading_result_screen_test.dart
git commit -m "feat(reading): show finalScore as a 4th stat card on the result screen"
```

---

### Task 4: Listening comprehension — auto-continue to the next turn

**Files:**
- Modify: `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`
- Modify: `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`

**Interfaces:**
- Consumes: existing `ListeningSessionState.playToken` supersede mechanism (unchanged).
- Produces: `playCurrentTurn()` keeps its exact signature (`Future<void> playCurrentTurn()`); its only behavior change is auto-advancing `currentTurnIndex` when a turn finishes without being superseded.

- [ ] **Step 1: Write the failing tests**

In `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`, add `import 'dart:async';` at the top, and add these two tests after the existing `'playCurrentTurn() speaks the current turn...'` test:

```dart
  test('playCurrentTurn() auto-continues through every turn until the last one', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.playCurrentTurn();

    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0)).called(1);
    verify(() => mockTts.speak('Yes, I need a room for tonight.', Language.english, pitch: 1.3))
        .called(1);
    verify(() => mockTts.speak('Sure, for how many guests?', Language.english, pitch: 1.0))
        .called(1);
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 2); // last turn
    expect(state.isSpeaking, false);
  });

  test('interrupting playback via stopPlayback() cancels the auto-continue chain', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    final completer = Completer<void>();
    when(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch')))
        .thenAnswer((_) => completer.future);

    final playFuture = notifier.playCurrentTurn();
    await notifier.stopPlayback(); // supersedes the in-flight turn 0 playback
    completer.complete(); // let the original (now-superseded) speak() resolve
    await playFuture;

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0); // stopPlayback() doesn't change turns
    verify(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'))).called(1); // no auto-continue
  });
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: FAIL — `'playCurrentTurn() auto-continues through every turn until the last one'` fails because today `playCurrentTurn()` only speaks turn 0 and stops. The interruption test may pass by coincidence (no auto-continue exists yet) — that's fine, it becomes a real regression guard after Step 3.

- [ ] **Step 3: Implement auto-continue in `playCurrentTurn()`**

In `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`, replace:

```dart
  Future<void> playCurrentTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(isSpeaking: true, playToken: token));
    final turn = current.currentTurn;
    await ref.read(ttsServiceProvider).speak(
          turn.text,
          current.passage.targetLanguage,
          pitch: _pitchFor(turn.speaker),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

with:

```dart
  Future<void> playCurrentTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(isSpeaking: true, playToken: token));
    final turn = current.currentTurn;
    await ref.read(ttsServiceProvider).speak(
          turn.text,
          current.passage.targetLanguage,
          pitch: _pitchFor(turn.speaker),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    if (latest.currentTurnIndex < latest.passage.turns.length - 1) {
      // Turn finished naturally (not interrupted) and it's not the last one
      // — keep going without a gap, staying "isSpeaking" the whole time.
      state = AsyncData(latest.copyWith(currentTurnIndex: latest.currentTurnIndex + 1));
      await playCurrentTurn();
      return;
    }
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: PASS — all tests green, including the pre-existing `nextTurn()`/`previousTurn()`/`seekToWord()` tests (unaffected).

- [ ] **Step 5: Run the full listening test suite to check for regressions**

Run: `flutter test test/features/listening/`
Expected: PASS — `comprehension_session_screen_test.dart` and other listening tests still pass unchanged.

- [ ] **Step 6: Commit**

```bash
git add lib/features/listening/presentation/providers/listening_comprehension_provider.dart test/features/listening/presentation/providers/listening_comprehension_provider_test.dart
git commit -m "feat(listening): auto-continue to the next turn after each one finishes"
```

---

## Final check

- [ ] Run the whole suite once: `flutter test`
- [ ] Expected: PASS, no regressions across `practice`, `reading`, and `listening` features.
