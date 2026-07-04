# Plan 4 — Firebase Sync + Settings Screen + Practice Level Filter: Navigation Index

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Spec file:** `docs/superpowers/specs/2026-07-02-plan4-firebase-settings-practice-filter-design.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**BASE commit:** `889944a`

## Dependency Chain

```
Task 01 (packages + Firebase init + SharedPreferences init + sharedPreferencesProvider)
  ├─ Task 02 (UserSettingsState + SharedPreferences persistence)
  │    └─ Task 04 (PracticeHomeScreen CEFR filter — reads targetCefrLevel from settings)
  ├─ Task 03 (CEFR filter in VocabRepository + GetVocabListUseCase)
  │    └─ Task 04 (PracticeHomeScreen CEFR filter — passes maxCefrLevel to use case)
  ├─ Task 05 (AppShell 4th tab + /settings route + placeholder SettingsScreen)
  └─ Task 06 (AuthNotifier — Google Sign-In)
       └─ Task 07 (SyncService + SyncNotifier — watches authNotifierProvider)
            └─ Task 08 (SettingsScreen full UI — uses authNotifier, syncNotifier, userSettings)
```

Tasks 02 and 03 can run in parallel.
Tasks 04, 05, and 06 can run in parallel (each needs only Task 01 + their respective Task 02/03).
Task 07 needs Tasks 02 + 06.
Task 08 needs Tasks 02 + 05 + 06 + 07.

## Task Files

| # | File | Description | Status | Commits |
|---|------|-------------|--------|---------|
| 01 | [plan4-task-01.md](plan4-task-01.md) | Packages + Firebase init + SharedPreferences | ⬜ pending | — |
| 02 | [plan4-task-02.md](plan4-task-02.md) | UserSettingsState + SharedPrefs persistence | ⬜ pending | — |
| 03 | [plan4-task-03.md](plan4-task-03.md) | CEFR filter in VocabRepository + UseCase | ⬜ pending | — |
| 04 | [plan4-task-04.md](plan4-task-04.md) | PracticeHomeScreen CEFR filter UI | ⬜ pending | — |
| 05 | [plan4-task-05.md](plan4-task-05.md) | AppShell 4th tab + /settings route | ⬜ pending | — |
| 06 | [plan4-task-06.md](plan4-task-06.md) | AuthNotifier (Google Sign-In) | ⬜ pending | — |
| 07 | [plan4-task-07.md](plan4-task-07.md) | SyncService + SyncNotifier | ⬜ pending | — |
| 08 | [plan4-task-08.md](plan4-task-08.md) | SettingsScreen full UI | ⬜ pending | — |

## Progress Ledger

<!-- Append one line per completed task: "Task N: complete (commit <sha>, review clean)" -->
