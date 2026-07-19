# Nghe chép Difficulty Levels — Task 01: DictationDifficulty + BlankSpan + SelectDictationBlanksUseCase

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** none (can start immediately)

## Global Constraints
(see `dictation-difficulty-global-constraints.md`)

## What This Task Delivers
Three small, pure additions with no dependency on the rest of the feature: `DictationDifficulty` (enum: easy/medium/hard, with a Vietnamese `.label`), `BlankSpan` (a value object describing one blank's position in a tokenized word list), and `SelectDictationBlanksUseCase` (a pure function that, given a sentence and a difficulty, returns the blank(s) to punch into it). No AI, no Riverpod, no widgets — fully unit-testable in isolation.

## Files
- Create: `lib/features/listening/domain/entities/dictation_difficulty.dart`
- Create: `lib/features/listening/domain/entities/blank_span.dart`
- Create: `lib/features/listening/domain/use_cases/select_dictation_blanks_use_case.dart`
- Create: `test/features/listening/domain/entities/dictation_difficulty_test.dart`
- Create: `test/features/listening/domain/entities/blank_span_test.dart`
- Create: `test/features/listening/domain/use_cases/select_dictation_blanks_use_case_test.dart`

## Produces (used by Task 02+)
- `enum DictationDifficulty { easy, medium, hard }` with `String get label`
- `BlankSpan({required int startWordIndex, required int wordCount})`
- `SelectDictationBlanksUseCase().execute(String sentence, DictationDifficulty difficulty, {Random? random}) → List<BlankSpan>`

## Steps

- [ ] **Step 1: Write the failing tests for DictationDifficulty**

Create `test/features/listening/domain/entities/dictation_difficulty_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';

void main() {
  test('label is the correct Vietnamese text for each value', () {
    expect(DictationDifficulty.easy.label, 'Dễ');
    expect(DictationDifficulty.medium.label, 'Trung bình');
    expect(DictationDifficulty.hard.label, 'Khó');
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/domain/entities/dictation_difficulty_test.dart
```

Expected: FAIL — `dictation_difficulty.dart` doesn't exist yet.

- [ ] **Step 3: Create dictation_difficulty.dart**

Create `lib/features/listening/domain/entities/dictation_difficulty.dart`:

```dart
enum DictationDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        DictationDifficulty.easy => 'Dễ',
        DictationDifficulty.medium => 'Trung bình',
        DictationDifficulty.hard => 'Khó',
      };
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
flutter test test/features/listening/domain/entities/dictation_difficulty_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write the failing test for BlankSpan**

Create `test/features/listening/domain/entities/blank_span_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/listening/domain/entities/blank_span.dart';

void main() {
  test('holds startWordIndex and wordCount', () {
    const span = BlankSpan(startWordIndex: 3, wordCount: 2);
    expect(span.startWordIndex, 3);
    expect(span.wordCount, 2);
  });
}
```

- [ ] **Step 6: Run test to confirm it fails, then create blank_span.dart**

```bash
flutter test test/features/listening/domain/entities/blank_span_test.dart
```

Expected: FAIL — `blank_span.dart` doesn't exist yet.

Create `lib/features/listening/domain/entities/blank_span.dart`:

```dart
/// Describes one blank as a range in a sentence's whitespace-tokenized word
/// list: words at indices [startWordIndex, startWordIndex + wordCount) are
/// hidden and must be filled in.
final class BlankSpan {
  const BlankSpan({required this.startWordIndex, required this.wordCount});

  final int startWordIndex;
  final int wordCount;
}
```

Run again to confirm it passes:

```bash
flutter test test/features/listening/domain/entities/blank_span_test.dart
```

Expected: PASS.

- [ ] **Step 7: Write the failing tests for SelectDictationBlanksUseCase**

Create `test/features/listening/domain/use_cases/select_dictation_blanks_use_case_test.dart`:

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
import 'package:lexi_core/features/listening/domain/use_cases/select_dictation_blanks_use_case.dart';

String _sentence(int wordCount) =>
    List.generate(wordCount, (i) => 'w$i').join(' ');

void main() {
  final useCase = SelectDictationBlanksUseCase();

  group('hard difficulty', () {
    test('returns no blanks', () {
      final blanks = useCase.execute(_sentence(12), DictationDifficulty.hard);
      expect(blanks, isEmpty);
    });
  });

  group('easy difficulty', () {
    test('returns exactly 2 single-word blanks', () {
      final blanks = useCase.execute(
        _sentence(12),
        DictationDifficulty.easy,
        random: Random(1),
      );
      expect(blanks.length, 2);
      for (final b in blanks) {
        expect(b.wordCount, 1);
      }
    });

    test('blanks are distinct, non-adjacent, and avoid the first/last word '
        'for a 12-word sentence, across many random seeds', () {
      for (var seed = 0; seed < 100; seed++) {
        final blanks = useCase.execute(
          _sentence(12),
          DictationDifficulty.easy,
          random: Random(seed),
        );
        expect(blanks.length, 2, reason: 'seed=$seed');
        final indices = blanks.map((b) => b.startWordIndex).toList()..sort();
        expect(indices[0], isNot(indices[1]), reason: 'seed=$seed');
        expect(indices[1] - indices[0], greaterThanOrEqualTo(2),
            reason: 'seed=$seed');
        expect(indices[0], greaterThanOrEqualTo(1), reason: 'seed=$seed');
        expect(indices[1], lessThanOrEqualTo(10), reason: 'seed=$seed');
      }
    });

    test('still returns 2 distinct blanks for a short (3-word) sentence, '
        'across many random seeds', () {
      for (var seed = 0; seed < 50; seed++) {
        final blanks = useCase.execute(
          _sentence(3),
          DictationDifficulty.easy,
          random: Random(seed),
        );
        expect(blanks.length, 2, reason: 'seed=$seed');
        final indices = blanks.map((b) => b.startWordIndex).toSet();
        expect(indices.length, 2, reason: 'seed=$seed');
        for (final b in blanks) {
          expect(b.startWordIndex, inInclusiveRange(0, 2), reason: 'seed=$seed');
        }
      }
    });
  });

  group('medium difficulty', () {
    test('returns exactly 1 multi-word blank spanning ~35% of a 12-word sentence', () {
      final blanks = useCase.execute(
        _sentence(12),
        DictationDifficulty.medium,
        random: Random(1),
      );
      expect(blanks.length, 1);
      expect(blanks.single.wordCount, 4); // round(12 * 0.35) == 4
    });

    test('span always leaves at least 1 word of context on each side, '
        'across many random seeds', () {
      for (var seed = 0; seed < 100; seed++) {
        final blanks = useCase.execute(
          _sentence(12),
          DictationDifficulty.medium,
          random: Random(seed),
        );
        expect(blanks.length, 1, reason: 'seed=$seed');
        final span = blanks.single;
        expect(span.startWordIndex, greaterThanOrEqualTo(1), reason: 'seed=$seed');
        expect(span.startWordIndex + span.wordCount, lessThanOrEqualTo(11),
            reason: 'seed=$seed');
      }
    });

    test('span length is clamped between 2 and wordCount-2 for a range of sentence lengths', () {
      for (final wordCount in [4, 5, 6, 10, 18]) {
        for (var seed = 0; seed < 20; seed++) {
          final blanks = useCase.execute(
            _sentence(wordCount),
            DictationDifficulty.medium,
            random: Random(seed),
          );
          expect(blanks.length, 1, reason: 'wordCount=$wordCount seed=$seed');
          expect(blanks.single.wordCount, greaterThanOrEqualTo(2),
              reason: 'wordCount=$wordCount seed=$seed');
          expect(blanks.single.wordCount, lessThanOrEqualTo(wordCount - 2),
              reason: 'wordCount=$wordCount seed=$seed');
        }
      }
    });
  });
}
```

- [ ] **Step 8: Run test to confirm it fails**

```bash
flutter test test/features/listening/domain/use_cases/select_dictation_blanks_use_case_test.dart
```

Expected: FAIL — `select_dictation_blanks_use_case.dart` doesn't exist.

- [ ] **Step 9: Create SelectDictationBlanksUseCase**

Create `lib/features/listening/domain/use_cases/select_dictation_blanks_use_case.dart`:

```dart
import 'dart:math';
import '../entities/blank_span.dart';
import '../entities/dictation_difficulty.dart';

/// Computes which word(s) of an already-generated dictation sentence should
/// be blanked out, based on the chosen difficulty. Pure and deterministic
/// given a [random] — no AI, no I/O, no dependency on how the sentence was
/// generated.
class SelectDictationBlanksUseCase {
  const SelectDictationBlanksUseCase();

  List<BlankSpan> execute(
    String sentence,
    DictationDifficulty difficulty, {
    Random? random,
  }) {
    final rand = random ?? Random();
    final wordCount = _wordCount(sentence);

    return switch (difficulty) {
      DictationDifficulty.hard => const [],
      DictationDifficulty.easy => _selectEasyBlanks(wordCount, rand),
      DictationDifficulty.medium => _selectMediumBlanks(wordCount, rand),
    };
  }

  int _wordCount(String sentence) =>
      sentence.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  List<BlankSpan> _selectEasyBlanks(int wordCount, Random rand) {
    if (wordCount <= 1) {
      return [const BlankSpan(startWordIndex: 0, wordCount: 1)];
    }
    final minIndex = wordCount >= 6 ? 1 : 0;
    final maxIndex = wordCount >= 6 ? wordCount - 2 : wordCount - 1;
    final range = maxIndex - minIndex + 1;

    int first = minIndex + rand.nextInt(range);
    int second = minIndex + rand.nextInt(range);

    var attempts = 0;
    // Prefer non-adjacent indices when the range allows it; always avoid
    // picking the exact same index twice.
    while ((second == first || (range >= 3 && (second - first).abs() < 2)) &&
        attempts < 30) {
      second = minIndex + rand.nextInt(range);
      attempts++;
    }
    if (second == first) {
      second = first == maxIndex ? first - 1 : first + 1;
    }

    final indices = <int>{first, second}.toList()..sort();
    return indices
        .map((i) => BlankSpan(startWordIndex: i, wordCount: 1))
        .toList();
  }

  List<BlankSpan> _selectMediumBlanks(int wordCount, Random rand) {
    if (wordCount <= 3) {
      return [BlankSpan(startWordIndex: 0, wordCount: wordCount)];
    }
    final spanLength = (wordCount * 0.35).round().clamp(2, wordCount - 2);
    final maxStartIndexInclusive = wordCount - spanLength - 1;
    final startIndex = maxStartIndexInclusive > 1
        ? 1 + rand.nextInt(maxStartIndexInclusive)
        : 1;
    return [BlankSpan(startWordIndex: startIndex, wordCount: spanLength)];
  }
}
```

- [ ] **Step 10: Run test to confirm it passes**

```bash
flutter test test/features/listening/domain/use_cases/select_dictation_blanks_use_case_test.dart
```

Expected: all tests pass (the seed loops mean this exercises ~270 random trials total — if any fails, re-check the arithmetic in Step 9 against the failing seed's `wordCount`, don't just re-run hoping it passes).

- [ ] **Step 11: Run all listening tests**

```bash
flutter test test/features/listening/
```

Expected: all tests pass (no regressions in existing Dictation tests — this task added no dependency on them).

- [ ] **Step 12: Analyze**

```bash
flutter analyze lib/features/listening/domain/
```

Expected: no issues.

- [ ] **Step 13: Commit**

```bash
git add lib/features/listening/domain/entities/dictation_difficulty.dart \
        lib/features/listening/domain/entities/blank_span.dart \
        lib/features/listening/domain/use_cases/select_dictation_blanks_use_case.dart \
        test/features/listening/domain/entities/dictation_difficulty_test.dart \
        test/features/listening/domain/entities/blank_span_test.dart \
        test/features/listening/domain/use_cases/select_dictation_blanks_use_case_test.dart
git commit -m "feat(dictation-difficulty): add DictationDifficulty, BlankSpan, SelectDictationBlanksUseCase"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
