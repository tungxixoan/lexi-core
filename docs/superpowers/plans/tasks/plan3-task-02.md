# Plan 3 — Task 02: ComputeSm2UseCase + Unit Tests

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01 (VocabRecord with SM-2 fields)

## Global Constraints
(see `plan3-global-constraints.md`)
- Tests use `flutter_test` — no mocktail needed (pure function, no mocks)

## What This Task Delivers

Pure SM-2 algorithm as a `const` use case. TDD: tests first, then implementation.

## Files

- Create: `lib/features/practice/domain/use_cases/compute_sm2_use_case.dart`
- Create: `test/features/practice/domain/use_cases/compute_sm2_use_case_test.dart`

## SM-2 Algorithm

```
compute(VocabRecord record, int quality) → VocabRecord:
  if quality < 3:
    sm2Repetitions = 0, sm2Interval = 1, nextReviewAt = now + 1 day
  else:
    newInterval = repetitions==0 → 1, repetitions==1 → 6, else → round(interval * easeFactor)
    newEF = clamp(easeFactor + 0.1 - (5-quality)*0.08, min: 1.3, max: 2.5)
    sm2Repetitions += 1, sm2Interval = newInterval, sm2EaseFactor = newEF
    nextReviewAt = now + newInterval days
  updatedAt = now
```

## Produces (used by Task 09)

```dart
class ComputeSm2UseCase {
  const ComputeSm2UseCase();
  VocabRecord compute(VocabRecord record, int quality) { ... }
}
```

## Status: ✅ complete — commit 7954f52 (13/13 tests pass, 54/54 full suite)
