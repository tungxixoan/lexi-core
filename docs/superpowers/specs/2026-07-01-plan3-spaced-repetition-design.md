# LexiCore Plan 3 — Spaced Repetition + Auto Exercises

**Date:** 2026-07-01
**Status:** Approved for implementation

---

## Goal

Add a Practice tab where users select words from their VocabBank and run a mixed-exercise session (flashcard + AI-generated quiz). After each session, the SM-2 spaced-repetition algorithm updates each word's review schedule.

---

## Architecture

New feature module `lib/features/practice/` following the same Clean Architecture pattern as `dictionary` and `vocabulary`. Reads VocabBank data via existing `vocabRepositoryProvider` and `GetVocabListUseCase` — does not duplicate storage.

---

## Session Flow

```
PracticeHomeScreen
  User picks: topic filter (from topicsNotifierProvider) + word count (5 / 10 / 20 / All)
  → Load words via GetVocabListUseCase (filtered by topic)
  → Shuffle → build exercise queue

PracticeSessionScreen
  Loop through queue:
    - New word (sm2Repetitions == 0): always FlashcardExercise
    - Reviewed word: random pick — Flashcard 30% / MultipleChoice 40% / FillInBlank 20% / Translation 10%
    - Translation only when sm2Repetitions >= 2
    - Lazy generation: while user answers card N, generate exercise for card N+1 in background (Gemini)
    - Flashcard: user taps "Biết" (quality 5) or "Không biết" (quality 1)
    - Quiz (MultipleChoice, FillInBlank, Translation): auto-graded — correct → quality 5, incorrect → quality 1
    - Record ExerciseResult(vocabRecordId, quality, isCorrect) in memory

SessionResultScreen
  Show summary: X/Y correct, per-word breakdown
  Trigger SM-2 update for all results (background, non-blocking):
    ComputeSm2UseCase.compute(record, quality) → UpdateVocabUseCase.execute(updated)
```

---

## Exercise Types

Sealed class `Exercise` with 4 subtypes:

| Subtype | Content | Grading |
|---------|---------|---------|
| `FlashcardExercise` | headword → flip → meaning + IPA + examples | User: "Biết" / "Không biết" |
| `MultipleChoiceExercise` | question + 4 options + correctIndex | Auto: tap correct option |
| `FillInBlankExercise` | sentence with `___` + expected answer | Auto: lowercase trim compare |
| `TranslationExercise` | prompt sentence + answer key | Auto: compare with Gemini-provided answer |

---

## Gemini Exercise Generation

`ExerciseGeneratorSource` sends one prompt per word, receives JSON:

**Input fields:** headword, meaning, examples (list), cefrLevel, inputType (word/phrase), targetLanguage

**Output (one of):**
```json
{ "type": "multiple_choice", "question": "...", "options": ["...", "...", "...", "..."], "correctIndex": 1 }
{ "type": "fill_in_blank", "sentence": "The ___ beauty lasts only a moment.", "answer": "ephemeral" }
{ "type": "translation", "prompt": "Dịch sang tiếng Việt: '...'", "answer": "..." }
```

Gemini selects the exercise type based on CEFR level and inputType. Fallback: if Gemini fails or returns unparseable JSON, serve a `FlashcardExercise` instead (no crash, no loading failure).

Model: `gemini-2.5-flash` (same as Plan 1 dictionary lookup).

---

## SM-2 Algorithm

`ComputeSm2UseCase` — pure Dart function, no side effects:

```
compute(VocabRecord record, int quality) → VocabRecord:
  if quality < 3:
    sm2Repetitions = 0
    sm2Interval = 1
    nextReviewAt = now + 1 day
  else:
    newInterval = if repetitions==0 → 1, if repetitions==1 → 6, else → round(interval * easeFactor)
    newEF = clamp(easeFactor + 0.1 - (5-quality)*0.08, min: 1.3, max: 2.5)
    sm2Repetitions += 1
    sm2Interval = newInterval
    sm2EaseFactor = newEF
    nextReviewAt = now + newInterval days
  updatedAt = now
```

Quality mapping:
- Flashcard "Biết" → 5, "Không biết" → 1
- Quiz correct → 5, incorrect → 1

SM-2 update happens after `SessionResultScreen` is shown — runs in background, does not block navigation.

---

## Data Flow

- **No new Hive boxes** — only updates existing `VocabRecord` fields (`sm2Repetitions`, `sm2EaseFactor`, `sm2Interval`, `nextReviewAt`, `updatedAt`) via `UpdateVocabUseCase`
- **Session data is in-memory only** — `List<ExerciseResult>` lives in `PracticeSessionNotifier`, discarded after update
- `ExerciseResult(String vocabRecordId, int quality, bool isCorrect)` — not persisted

---

## Navigation

Add `/practice` routes to existing `ShellRoute` in `app_router.dart`:
- `/practice` → `PracticeHomeScreen`
- `/practice/session` → `PracticeSessionScreen` (receives `SessionConfig` via extra)
- `/practice/result` → `SessionResultScreen` (receives `SessionResult` via extra)

Add 3rd destination to `AppShell` NavigationBar: label "Luyện tập", `Icons.school_outlined` / `Icons.school`.

---

## File Map

### Create
```
lib/features/practice/
  domain/
    entities/
      exercise.dart                         sealed class Exercise + 4 subtypes
      exercise_result.dart                  ExerciseResult(vocabRecordId, quality, isCorrect)
    use_cases/
      generate_exercise_use_case.dart       calls ExerciseGeneratorSource, fallback to Flashcard
      compute_sm2_use_case.dart             pure SM-2 computation
  data/
    sources/
      exercise_generator_source.dart        Gemini prompt + JSON parse
  presentation/
    providers/
      practice_session_provider.dart        @riverpod AsyncNotifier for session state
    screens/
      practice_home_screen.dart             topic picker + word count + Start button
      practice_session_screen.dart          card display + lazy generate + result recording
      session_result_screen.dart            summary + SM-2 update trigger
    widgets/
      flashcard_widget.dart
      multiple_choice_widget.dart
      fill_in_blank_widget.dart
      translation_exercise_widget.dart
```

### Modify
```
lib/core/router/app_router.dart             add /practice routes to ShellRoute
lib/core/widgets/app_shell.dart             add 3rd NavigationBar destination
lib/core/di/app_providers.dart              add exerciseGeneratorSourceProvider, generateExerciseUseCaseProvider, computeSm2UseCaseProvider
```

### Tests
```
test/features/practice/domain/use_cases/
  compute_sm2_use_case_test.dart            ~10 unit tests: pass/fail paths, EF clamping, interval progression
  generate_exercise_use_case_test.dart      mock ExerciseGeneratorSource, verify fallback on error
```

---

## Global Constraints (inherited from Plans 1–2)

- Flutter SDK: >=3.22.0 · Dart SDK: >=3.4.0
- Riverpod 2.x: `@riverpod` annotation only — no StateNotifier/ChangeNotifier
- GoRouter: no `Navigator.push` for screen transitions
- All domain entities: immutable, `const` constructors, mutation via `copyWith`
- Gemini model: `gemini-2.5-flash`
- `aiEnabled` check before calling Gemini — if disabled, serve Flashcard only
- Plan 2 unit tests: mocktail; Plan 1 tests: mockito — both coexist
- Working directory: `d:/Flutter/lexi-core`

---

## Out of Scope (Plan 4+)

- "Ôn hôm nay" badge / due-date dashboard
- Streak tracking
- Difficulty ratings beyond binary (correct/incorrect)
- Firebase sync of SM-2 progress
