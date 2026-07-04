# Plan 2 — Vocabulary Bank + Topic System: Navigation Index

**Plan file:** `docs/superpowers/plans/2026-06-30-plan2-vocabulary-bank.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan2-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`

## Dependency Chain

```
Task 01 (Hive setup)
  └─ Task 02 (Domain entities)
       └─ Task 03 (VocabRepository interface)
            ├─ Task 04 (VocabRepositoryImpl)
            └─ Task 05 (Use cases) ← tests mock VocabRepository
                 └─ Task 06 (Riverpod providers + DI)
                      ├─ Task 07 (Save button + SaveVocabSheet)
                      ├─ Task 08 (App shell + bottom nav) ← parallel with 07
                      ├─ Task 09 (VocabBankScreen)
                      ├─ Task 10 (VocabDetailScreen)
                      └─ Task 11 (VocabBank lookup cache) ← modifies lookup_provider.dart
```

Tasks 07 and 08 are independent and can be done in either order (both need Task 06).
Tasks 09 and 10 need Task 08 (router) and Task 07 (for the full end-to-end flow).
Task 11 needs Task 06 (vocabRepositoryProvider). Modifies Plan 1 lookup_provider.dart to check VocabBank before calling API.

## Task Files

| # | File | Status | Commits |
|---|------|--------|---------|
| 01 | [plan2-task-01.md](plan2-task-01.md) | ✅ complete | c442123 |
| 02 | [plan2-task-02.md](plan2-task-02.md) | ⬜ pending | — |
| 03 | [plan2-task-03.md](plan2-task-03.md) | ⬜ pending | — |
| 04 | [plan2-task-04.md](plan2-task-04.md) | ⬜ pending | — |
| 05 | [plan2-task-05.md](plan2-task-05.md) | ⬜ pending | — |
| 06 | [plan2-task-06.md](plan2-task-06.md) | ⬜ pending | — |
| 07 | [plan2-task-07.md](plan2-task-07.md) | ⬜ pending | — |
| 08 | [plan2-task-08.md](plan2-task-08.md) | ⬜ pending | — |
| 09 | [plan2-task-09.md](plan2-task-09.md) | ⬜ pending | — |
| 10 | [plan2-task-10.md](plan2-task-10.md) | ⬜ pending | — |
| 11 | [plan2-task-11.md](plan2-task-11.md) | ⬜ pending | — |

## Progress Ledger

<!-- Append one line per completed task:
Task N: complete (commits <base7>..<head7>, review clean)
-->
Task 01: complete (commit c442123, review clean)
