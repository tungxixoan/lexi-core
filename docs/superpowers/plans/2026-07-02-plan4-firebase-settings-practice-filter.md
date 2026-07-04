# LexiCore Plan 4 — Firebase Sync + Settings Screen + Practice Level Filter

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.
> Individual task briefs are in `docs/superpowers/plans/tasks/plan4-task-{01..08}.md`.
> Global constraints: `docs/superpowers/plans/tasks/plan4-global-constraints.md`.

**Goal:** Persist user settings to disk, add a 4th Settings tab with Google Sign-In and Firestore cloud sync for VocabBank + Topics, and add a CEFR level filter to the Practice screen.

**Architecture:** Three slices built in order: (1) SharedPreferences settings persistence, (2) CEFR filter through repository → use case → Practice screen, (3) Firebase Auth + Firestore bidirectional sync as an opt-in infrastructure layer over existing Hive storage (offline-first: Hive is source of truth).

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod 2.x + riverpod_annotation, GoRouter, Hive (existing), SharedPreferences, firebase_core ^3.0.0, firebase_auth ^5.0.0, cloud_firestore ^5.0.0, google_sign_in ^6.0.0, mocktail (tests)

**BASE commit:** `889944a`
**Progress ledger:** `.superpowers/sdd/progress.md`

## Global Constraints

- Flutter SDK >=3.22.0, Dart >=3.4.0, iOS + Android only
- Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- `ref.read()` in async methods; `ref.watch()` only in `build()`
- GoRouter only — no `Navigator.push` for screen transitions
- **NEVER store `geminiApiKey` in Firestore** — local (SharedPreferences) only
- Firebase sign-in is entirely opt-in — all features work without it
- Offline-first: Hive is source of truth; Firestore is a mirror
- Firestore writes are best-effort — log failures, never crash the app
- Unit tests use `mocktail`

---

## File Map

```text
lib/
├── core/
│   ├── di/app_providers.dart              MODIFY — add syncService/authNotifier/userSettings providers
│   ├── router/app_router.dart             MODIFY — add /settings route to ShellRoute
│   ├── services/
│   │   └── sync_service.dart              CREATE — Firestore bidirectional sync
│   └── widgets/app_shell.dart             MODIFY — 4th NavigationBar destination
├── features/
│   ├── dictionary/
│   │   └── domain/entities/
│   │       └── user_settings_state.dart   CREATE — UserSettingsState (targetCefrLevel, geminiApiKey, etc.)
│   │   └── presentation/providers/
│   │       └── user_settings_provider.dart MODIFY — persist to SharedPreferences
│   ├── practice/
│   │   └── presentation/screens/
│   │       └── practice_home_screen.dart  MODIFY — CEFR filter UI
│   ├── settings/
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── auth_notifier.dart     CREATE — Google Sign-In state
│   │       │   └── sync_notifier.dart     CREATE — sync trigger + status
│   │       └── screens/
│   │           └── settings_screen.dart   CREATE — API key, sign-in, sync controls
│   └── vocabulary/
│       └── domain/repositories/
│           └── vocab_repository.dart      MODIFY — add maxCefrLevel param to getAll()

test/
├── core/services/sync_service_test.dart   CREATE
└── features/settings/presentation/providers/
    ├── auth_notifier_test.dart            CREATE
    └── sync_notifier_test.dart            CREATE
```

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | [Packages + Firebase init + SharedPreferences](tasks/plan4-task-01.md) | pubspec deps, sharedPreferencesProvider, Firebase init (commented until flutterfire configure) |
| 02 | [UserSettingsState + SharedPrefs persistence](tasks/plan4-task-02.md) | UserSettingsState entity, UserSettingsNotifier persisting to SharedPreferences |
| 03 | [CEFR filter in VocabRepository + UseCase](tasks/plan4-task-03.md) | `getAll(maxCefrLevel:)` param, filter in impl, use case update |
| 04 | [PracticeHomeScreen CEFR filter UI](tasks/plan4-task-04.md) | Level dropdown, reads targetCefrLevel from settings |
| 05 | [AppShell 4th tab + /settings route](tasks/plan4-task-05.md) | GoRouter /settings route, Settings destination in NavigationBar |
| 06 | [AuthNotifier (Google Sign-In)](tasks/plan4-task-06.md) | AuthNotifier with signIn/signOut, firebase_auth + google_sign_in |
| 07 | [SyncService + SyncNotifier](tasks/plan4-task-07.md) | Bidirectional Firestore sync, SyncNotifier with status |
| 08 | [SettingsScreen full UI](tasks/plan4-task-08.md) | API key dialog, Google Sign-In button, sync controls, CEFR target picker |
