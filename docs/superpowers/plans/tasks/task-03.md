# Task 3: Input Type Detector

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 2 (InputType enum exists at `lib/features/dictionary/domain/entities/input_type.dart`)

## Global Constraints
- No business logic in widgets
- All domain entities: immutable, `const` constructors

## What This Task Delivers
A static utility class that classifies a string as word, phrase, or sentence using a word-count + punctuation heuristic. Fully tested.

## Files
- Create: `lib/core/utils/input_detector.dart`
- Create: `test/core/utils/input_detector_test.dart`

## Produces (used by Tasks 6, 8)
- `InputDetector.detect(String input) → InputType`
  - Single token → `InputType.word`
  - 2–4 words, no terminal punctuation → `InputType.phrase`
  - 5+ words OR terminal `.`, `?`, `!` → `InputType.sentence`
  - Empty string → `InputType.word` (safe fallback)

## Steps

- [ ] **Step 1: Write failing tests**

```dart
// test/core/utils/input_detector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/input_detector.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';

void main() {
  group('InputDetector.detect', () {
    test('single word → word', () {
      expect(InputDetector.detect('follow'), InputType.word);
      expect(InputDetector.detect('technology'), InputType.word);
    });

    test('two words → phrase', () {
      expect(InputDetector.detect('follow up'), InputType.phrase);
    });

    test('three or four words → phrase', () {
      expect(InputDetector.detect('break a leg'), InputType.phrase);
      expect(InputDetector.detect('piece of cake'), InputType.phrase);
    });

    test('five or more words → sentence', () {
      expect(
        InputDetector.detect('Can you follow up with me'),
        InputType.sentence,
      );
    });

    test('terminal period → sentence regardless of word count', () {
      expect(InputDetector.detect('Good morning.'), InputType.sentence);
    });

    test('terminal question mark → sentence', () {
      expect(InputDetector.detect('Are you ready?'), InputType.sentence);
    });

    test('terminal exclamation → sentence', () {
      expect(InputDetector.detect('Watch out!'), InputType.sentence);
    });

    test('trims whitespace before classifying', () {
      expect(InputDetector.detect('  follow  '), InputType.word);
      expect(InputDetector.detect('  follow up  '), InputType.phrase);
    });

    test('empty string → word (safe fallback)', () {
      expect(InputDetector.detect(''), InputType.word);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/core/utils/input_detector_test.dart
```

Expected: compile error — `InputDetector` not defined.

- [ ] **Step 3: Implement input_detector.dart**

```dart
// lib/core/utils/input_detector.dart
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';

class InputDetector {
  InputDetector._();

  static const _phraseMaxWords = 4;
  static final _terminalPunctuation = RegExp(r'[.?!]\s*$');

  static InputType detect(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return InputType.word;
    if (_terminalPunctuation.hasMatch(trimmed)) return InputType.sentence;

    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    if (wordCount > _phraseMaxWords) return InputType.sentence;
    if (wordCount >= 2) return InputType.phrase;
    return InputType.word;
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/core/utils/input_detector_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/input_detector.dart test/core/utils/input_detector_test.dart
git commit -m "feat: add InputDetector with heuristic word/phrase/sentence classification"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed — `flutter test test/core/utils/input_detector_test.dart`
Concerns: (if any)
