# LexiCore Plan 9 — "Luyện nghe" Tab + Nghe chép (Dictation)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Luyện nghe" (Listening Practice) tab containing a hub screen with two entries, and fully build out the first of the two: "Nghe chép" (dictation) — AI generates one sentence from ~2 Vocab Bank words, the user listens (via `TtsService`) and types back what they heard, with unlimited-but-penalized replay and SM-2 spaced-repetition feedback. The second entry ("Nghe hiểu" / TOEIC-style comprehension) is a disabled "coming soon" card, built out in Plan 10.

**Architecture:** New `lib/features/listening/` module following Clean Architecture, structured exactly like `lib/features/reading/` (`DictationSource` calling the shared `AiClientFactory`, a `DictationPracticeNotifier` AsyncNotifier holding session state, screens for home/session/result). No new packages — audio playback reuses the existing `TtsService` (flutter_tts). The "Luyện nghe" tab reuses the width-based visibility fix already applied to the Reading tab (`constraints.maxWidth >= 600 || settings.showListeningPracticeOnMobile`), not `kIsWeb`.

**Tech Stack:** `AiClientFactory`/`GenerativeModelClient` (existing, provider-agnostic), Riverpod 2.x `@riverpod`, GoRouter, `uuid`, `flutter_tts` (via existing `TtsService`)

**BASE commit:** `<SET_AT_EXECUTION_START>`
**Progress ledger:** `.superpowers/sdd/progress.md`

**Spec:** [2026-07-19-listening-practice-design.md](../superpowers/specs/2026-07-19-listening-practice-design.md) §3, §5

## Global Constraints

(see `docs/superpowers/plans/tasks/plan9-global-constraints.md`)

---

## File Map

```text
lib/
├── features/
│   ├── listening/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── dictation_item.dart                  CREATE — DictationItem
│   │   │   └── use_cases/
│   │   │       └── generate_dictation_item_use_case.dart CREATE
│   │   ├── data/
│   │   │   └── sources/
│   │   │       └── dictation_source.dart                CREATE — AI prompt + JSON parse
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── dictation_practice_provider.dart      CREATE — DictationSessionState,
│   │       │                                                       DictationSessionResult, DictationPracticeNotifier
│   │       └── screens/
│   │           ├── listening_home_screen.dart             CREATE — hub, 2 cards
│   │           ├── dictation_home_screen.dart              CREATE
│   │           ├── dictation_session_screen.dart           CREATE
│   │           └── dictation_result_screen.dart            CREATE
│   ├── dictionary/domain/entities/
│   │   └── user_settings_state.dart                       MODIFY — add showListeningPracticeOnMobile
│   ├── dictionary/presentation/providers/
│   │   └── user_settings_provider.dart                    MODIFY — persist + expose the new field
│   └── settings/presentation/screens/
│       └── settings_screen.dart                           MODIFY — add toggle
├── core/
│   ├── di/app_providers.dart                              MODIFY — add DictationSource + use case DI
│   ├── router/app_router.dart                             MODIFY — add /listening routes
│   └── widgets/app_shell.dart                              MODIFY — add "Luyện nghe" tab (width-based)

test/
└── features/listening/
    ├── domain/entities/dictation_item_test.dart                            CREATE
    ├── data/sources/dictation_source_test.dart                             CREATE
    ├── domain/use_cases/generate_dictation_item_use_case_test.dart         CREATE
    ├── presentation/providers/dictation_practice_provider_test.dart        CREATE
    └── presentation/screens/
        ├── listening_home_screen_test.dart                                 CREATE
        ├── dictation_home_screen_test.dart                                 CREATE
        ├── dictation_session_screen_test.dart                              CREATE
        └── dictation_result_screen_test.dart                               CREATE
```

- `README.md` MODIFY — document the new feature (Task 08)

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | [Settings field + toggle](tasks/plan9-task-01.md) | `UserSettingsState.showListeningPracticeOnMobile`, Settings toggle |
| 02 | [DictationItem entity](tasks/plan9-task-02.md) | Single-sentence domain entity |
| 03 | [DictationSource + UseCase](tasks/plan9-task-03.md) | AI prompt → `DictationItem`; `GenerateDictationItemUseCase` |
| 04 | [Provider + DI + Router + AppShell + Hub](tasks/plan9-task-04.md) | `DictationPracticeNotifier`, DI wiring, `/listening` routes, "Luyện nghe" tab, real `ListeningHomeScreen` hub, stub Dictation screens |
| 05 | [DictationHomeScreen](tasks/plan9-task-05.md) | Ngôn ngữ/Chủ đề(Topic)/Cấp độ filters, error states, generate flow |
| 06 | [DictationSessionScreen](tasks/plan9-task-06.md) | Play/replay button, plain typing field, submit flow |
| 07 | [DictationResultScreen](tasks/plan9-task-07.md) | Score, diff view, SM-2 update, regenerate/home buttons |
| 08 | [Update README](tasks/plan9-task-08.md) | Document "Luyện nghe"/"Nghe chép" in Tính năng, Kiến trúc, Roadmap |
