# Plan 3 — Spaced Repetition + Auto Exercises: Navigation Index

**Plan file:** `docs/superpowers/plans/2026-07-01-plan3-spaced-repetition.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan3-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**BASE commit:** `d2210ca`

## Dependency Chain

```
Task 01 (Domain entities: Exercise, ExerciseResult, SessionConfig, SessionResult)
  ├─ Task 02 (ComputeSm2UseCase + tests) ← depends on VocabRecord only
  ├─ Task 03 (ExerciseGeneratorSource + GenerateExerciseUseCase + tests)
  │    └─ Task 04 (DI providers + /practice routes + AppShell 3rd tab + placeholder screens)
  │         ├─ Task 05 (PracticeSessionProvider — AsyncNotifier + lazy generation)
  │         │    ├─ Task 07 (PracticeHomeScreen)
  │         │    └─ Task 08 (PracticeSessionScreen) ← also needs Task 06
  │         └─ Task 06 (Exercise widgets: Flashcard, MultipleChoice, FillInBlank, Translation)
  │              └─ Task 09 (SessionResultScreen + SM-2 update) ← also needs Task 02
  └─ (Task 02 result feeds into Task 09's SM-2 update)
```

Tasks 02 and 03 can be done in parallel (both depend only on Task 01).
Tasks 07 and 08 need Task 05. Task 08 also needs Task 06.
Task 09 needs Tasks 02, 05, 06.

## Task Files

| # | File | Status | Commits |
|---|------|--------|---------|
| 01 | [plan3-task-01.md](plan3-task-01.md) | ✅ complete | 1ab54d0 |
| 02 | [plan3-task-02.md](plan3-task-02.md) | ✅ complete | 7954f52 |
| 03 | [plan3-task-03.md](plan3-task-03.md) | ⬜ pending | — |
| 04 | [plan3-task-04.md](plan3-task-04.md) | ⬜ pending | — |
| 05 | [plan3-task-05.md](plan3-task-05.md) | ⬜ pending | — |
| 06 | [plan3-task-06.md](plan3-task-06.md) | ⬜ pending | — |
| 07 | [plan3-task-07.md](plan3-task-07.md) | ⬜ pending | — |
| 08 | [plan3-task-08.md](plan3-task-08.md) | ⬜ pending | — |
| 09 | [plan3-task-09.md](plan3-task-09.md) | ⬜ pending | — |

## Progress Ledger

<!-- Append one line per completed task -->
Task 01: complete (commit 1ab54d0, review clean)
Task 02: complete (commit 7954f52, 13/13 tests, review pending)
