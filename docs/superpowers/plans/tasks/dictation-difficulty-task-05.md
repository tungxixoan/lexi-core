# Nghe chép Difficulty Levels — Task 05: DictationResultScreen Cloze Result View

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 02 (`DictationSessionResult.isBlankCorrect`/`targetTextFor`/`blockAccuracy`)

## Global Constraints
(see `dictation-difficulty-global-constraints.md`)

## What This Task Delivers
`DictationResultScreen` now branches on `result.difficulty`:
- **Khó:** exactly the existing `_DiffText` character-colored diff — **unchanged**.
- **Dễ/Trung bình:** a new read-only cloze rendering — each blank shows the user's answer in green (correct) or red with the correct word/phrase revealed alongside (incorrect); everything else renders as plain visible text.

The score, replay count, elapsed time, full correct sentence, Vietnamese translation, action buttons, and SM-2 update logic are all **already difficulty-agnostic** (they read `result.finalScore`/`result.sm2Quality`, which Task 02 already made difficulty-aware) — this task only changes which widget renders the "what you typed" section.

## Files
- Modify: `lib/features/listening/presentation/screens/dictation_result_screen.dart`
- Modify: `test/features/listening/presentation/screens/dictation_result_screen_test.dart`

## Interfaces
- Consumes: `DictationSessionResult.isBlankCorrect(int)`, `.targetTextFor(BlankSpan)`, `.blocks`/`.blankAnswers` (Task 02); `DictationDifficulty`, `BlankSpan` (Task 01)
- Produces: fully functional cloze result view; Khó's existing view unchanged

## Steps

- [ ] **Step 1: Write the failing tests**

In `test/features/listening/presentation/screens/dictation_result_screen_test.dart`, add these imports:

```dart
import 'package:lexi_core/features/listening/domain/entities/blank_span.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
```

Add this new group at the end of `main()`:

```dart
  group('cloze mode (Dễ/Trung bình)', () {
    // _testItem.target == 'Hello world.' — blank both words, one each.
    const clozeBlanks = [
      BlankSpan(startWordIndex: 0, wordCount: 1),
      BlankSpan(startWordIndex: 1, wordCount: 1),
    ];

    final clozeResult = DictationSessionResult(
      item: _testItem,
      typed: '',
      replayCount: 0,
      duration: const Duration(seconds: 3),
      difficulty: DictationDifficulty.easy,
      blanks: clozeBlanks,
      blankAnswers: const ['Hello', 'wrong'],
    );

    testWidgets(
        'shows the correct blank answer and reveals the right word for the wrong one',
        (tester) async {
      final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
      await tester.pumpWidget(_buildResult(clozeResult, repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello'), findsWidgets);
      expect(find.textContaining('wrong'), findsOneWidget);
      expect(find.textContaining('đúng: world.'), findsOneWidget);
    });

    testWidgets('shows the score based on blockAccuracy (1 of 2 blanks correct = 50%)',
        (tester) async {
      final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
      await tester.pumpWidget(_buildResult(clozeResult, repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('50'), findsWidgets);
    });

    testWidgets('still shows the full correct sentence and Vietnamese translation',
        (tester) async {
      final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
      await tester.pumpWidget(_buildResult(clozeResult, repo));
      await tester.pumpAndSettle();
      expect(find.text('Hello world.'), findsOneWidget); // "Câu đúng" section
      expect(find.text('Xin chào thế giới.'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/dictation_result_screen_test.dart
```

Expected: FAIL — no "đúng: world." reveal text exists yet (Khó's `_DiffText` renders `blankAnswers`/`blanks` unaware).

- [ ] **Step 3: Update dictation_result_screen.dart**

In `lib/features/listening/presentation/screens/dictation_result_screen.dart`, add this import:

```dart
import '../../domain/entities/dictation_difficulty.dart';
```

Find this exact block (in `build()`):

```dart
            Text('Bạn đã gõ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _DiffText(
              typed: result.typed,
              target: result.item.target,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
```

Replace it with:

```dart
            Text('Bạn đã gõ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (result.difficulty == DictationDifficulty.hard)
              _DiffText(
                typed: result.typed,
                target: result.item.target,
                style: theme.textTheme.bodyLarge,
              )
            else
              _ClozeResult(result: result),
            const SizedBox(height: 16),
```

Add this new widget class at the end of the file, after `_DiffText`:

```dart

class _ClozeResult extends StatelessWidget {
  const _ClozeResult({required this.result});
  final DictationSessionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final words = result.item.target
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final spans = <InlineSpan>[];
    var wordIndex = 0;
    for (var blankIdx = 0; blankIdx < result.blanks.length; blankIdx++) {
      final blank = result.blanks[blankIdx];
      if (blank.startWordIndex > wordIndex) {
        final visible = words.sublist(wordIndex, blank.startWordIndex).join(' ');
        spans.add(TextSpan(text: '$visible ', style: baseStyle));
      }
      final isCorrect = result.isBlankCorrect(blankIdx);
      final answer = result.blankAnswers[blankIdx];
      spans.add(TextSpan(
        text: answer.isEmpty ? '___' : answer,
        style: baseStyle.copyWith(
          color: isCorrect ? Colors.green : theme.colorScheme.error,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ));
      if (!isCorrect) {
        spans.add(TextSpan(
          text: ' (đúng: ${result.targetTextFor(blank)})',
          style: baseStyle.copyWith(
            color: theme.colorScheme.error,
            fontStyle: FontStyle.italic,
          ),
        ));
      }
      spans.add(TextSpan(text: ' ', style: baseStyle));
      wordIndex = blank.startWordIndex + blank.wordCount;
    }
    if (wordIndex < words.length) {
      spans.add(TextSpan(text: words.sublist(wordIndex).join(' '), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/listening/presentation/screens/dictation_result_screen_test.dart
```

Expected: all tests pass — the original 5 Khó-mode tests (unmodified) plus the 3 new cloze-mode tests.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/listening/presentation/screens/dictation_result_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Verify final web build**

```bash
flutter build web --release
```

Expected: builds successfully.

- [ ] **Step 8: Commit**

```bash
git add lib/features/listening/presentation/screens/dictation_result_screen.dart \
        test/features/listening/presentation/screens/dictation_result_screen_test.dart
git commit -m "feat(dictation-difficulty): add cloze result view to DictationResultScreen for Dễ/Trung bình"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Build: web results
Concerns: (if any)
