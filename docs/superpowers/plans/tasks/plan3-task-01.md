# Plan 3 — Task 01: Practice Domain Entities

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 2 complete (`VocabRecord` entity with SM-2 fields exists)

## Global Constraints
(see `plan3-global-constraints.md`)

## What This Task Delivers

Pure domain entities for the Practice feature — no logic, no API, no tests.

## Files

- Create: `lib/features/practice/domain/entities/exercise.dart`
- Create: `lib/features/practice/domain/entities/exercise_result.dart`

## Produces (used by all Plan 3 tasks)

```dart
// exercise.dart
sealed class Exercise { final VocabRecord vocabRecord; }
final class FlashcardExercise extends Exercise
final class MultipleChoiceExercise extends Exercise {
  final String question;
  final List<String> options; // always 4
  final int correctIndex;     // 0-3
}
final class FillInBlankExercise extends Exercise {
  final String sentence; // contains '___'
  final String answer;   // lowercase
}
final class TranslationExercise extends Exercise {
  final String prompt;
  final String answer;
}

// exercise_result.dart
final class ExerciseResult { final String vocabRecordId; final int quality; final bool isCorrect; }
final class SessionConfig { final List<VocabRecord> words; }
final class SessionResult {
  final List<ExerciseResult> results;
  final List<VocabRecord> words;
  int get correctCount;
  int get totalCount;
}
```

## Status: ✅ complete — commit 1ab54d0
