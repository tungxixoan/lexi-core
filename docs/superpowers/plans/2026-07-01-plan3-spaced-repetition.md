# LexiCore Plan 3 — Spaced Repetition + Auto Exercises

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.
> Individual task briefs are in `docs/superpowers/plans/tasks/plan3-task-{01..09}.md`.
> Global constraints: `docs/superpowers/plans/tasks/plan3-global-constraints.md`.

**Goal:** Add a Practice tab where users select words from their VocabBank and run a mixed exercise session (flashcard + Gemini-generated quiz), updating SM-2 review schedules after each session.

**Architecture:** New `lib/features/practice/` module (Clean Architecture). Reads VocabBank via existing `vocabRepositoryProvider` and `getVocabListUseCaseProvider`. Session state lives in a Riverpod `AsyncNotifier`. Exercises generated lazily via Gemini. SM-2 update runs in background after session result screen is shown.

**BASE commit:** `d2210ca`
**Progress ledger:** `.superpowers/sdd/progress.md`

## File Map

```
lib/features/practice/
  domain/
    entities/
      exercise.dart                    sealed class Exercise + 4 subtypes        Task 01 ✅
      exercise_result.dart             ExerciseResult + SessionConfig + SessionResult  Task 01 ✅
    use_cases/
      compute_sm2_use_case.dart        pure SM-2 computation                     Task 02 ✅
      generate_exercise_use_case.dart  aiEnabled check + fallback to Flashcard   Task 03 ✅
  data/
    sources/
      exercise_generator_source.dart   Gemini prompt + JSON parse                Task 03 ✅
  presentation/
    providers/
      practice_session_provider.dart   @riverpod AsyncNotifier, lazy generation  Task 05
    screens/
      practice_home_screen.dart        topic filter + word count + Start          Task 07
      practice_session_screen.dart     card display + lazy gen + result recording Task 08
      session_result_screen.dart       summary + SM-2 update trigger              Task 09
    widgets/
      flashcard_widget.dart            FlashcardExercise UI                       Task 06
      multiple_choice_widget.dart      MultipleChoiceExercise UI                  Task 06
      fill_in_blank_widget.dart        FillInBlankExercise UI                     Task 06
      translation_exercise_widget.dart TranslationExercise UI                     Task 06

lib/core/
  router/app_router.dart               +/practice routes                          Task 04
  widgets/app_shell.dart               +3rd NavigationBar destination             Task 04
  di/app_providers.dart                +exerciseGeneratorSource/generateExercise/computeSm2  Task 04

test/features/practice/domain/use_cases/
  compute_sm2_use_case_test.dart       13 tests                                   Task 02 ✅
  generate_exercise_use_case_test.dart  3 tests                                   Task 03 ✅
```

## Task Index

| # | Task file | Status |
|---|-----------|--------|
| 01 | [plan3-task-01.md](tasks/plan3-task-01.md) | ✅ complete |
| 02 | [plan3-task-02.md](tasks/plan3-task-02.md) | ✅ complete |
| 03 | [plan3-task-03.md](tasks/plan3-task-03.md) | ✅ complete |
| 04 | [plan3-task-04.md](tasks/plan3-task-04.md) | ⬜ pending |
| 05 | [plan3-task-05.md](tasks/plan3-task-05.md) | ⬜ pending |
| 06 | [plan3-task-06.md](tasks/plan3-task-06.md) | ⬜ pending |
| 07 | [plan3-task-07.md](tasks/plan3-task-07.md) | ⬜ pending |
| 08 | [plan3-task-08.md](tasks/plan3-task-08.md) | ⬜ pending |
| 09 | [plan3-task-09.md](tasks/plan3-task-09.md) | ⬜ pending |
