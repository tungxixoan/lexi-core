# LexiCore Plan 7 — "Luyện đọc & gõ" Bilingual Reading Feature

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the "Luyện đọc & gõ" feature — AI generates a 4–6 sentence bilingual passage from the user's Vocab Bank; the user reads the target-language text and types each sentence while seeing the Vietnamese translation, with character-level accuracy feedback.

**Architecture:** New `lib/features/reading/` module following Clean Architecture. `ReadingPassageSource` calls Gemini once to generate a `ReadingPassage` (list of `BilingualSentence`). `ReadingPracticeNotifier` (Riverpod AsyncNotifier) holds generation state and live session state (current sentence index, typed text, completed results). The session screen uses a transparent `TextField` overlaid with a `RichText` for character-by-character coloring. The reading tab is always visible on web, opt-in on mobile via `showReadingPracticeOnMobile` (Plan 6 Task 03).

**Tech Stack:** `google_generative_ai` (Gemini 2.5 Flash), Riverpod 2.x `@riverpod`, GoRouter, `uuid`

**BASE commit:** `<SET_AT_EXECUTION_START — must be after Plan 6 is complete>`
**Progress ledger:** `.superpowers/sdd/progress.md`

## Global Constraints

(see `docs/superpowers/plans/tasks/plan7-global-constraints.md`)

---

## File Map

```text
lib/
├── features/
│   └── reading/
│       ├── domain/
│       │   └── entities/
│       │       └── reading_passage.dart          CREATE — ReadingPassage, BilingualSentence
│       ├── data/
│       │   └── sources/
│       │       └── reading_passage_source.dart   CREATE — Gemini prompt + JSON parse
│       ├── domain/
│       │   └── use_cases/
│       │       └── generate_reading_passage_use_case.dart  CREATE
│       └── presentation/
│           ├── providers/
│           │   └── reading_practice_provider.dart CREATE — SentenceResult, ReadingSessionState,
│           │                                               ReadingSessionResult, ReadingPracticeNotifier
│           └── screens/
│               ├── reading_home_screen.dart       CREATE
│               ├── reading_session_screen.dart    CREATE
│               └── reading_result_screen.dart     CREATE
├── core/
│   ├── di/app_providers.dart                      MODIFY — add ReadingPassageSource + use case DI
│   ├── router/app_router.dart                     MODIFY — add /reading routes
│   └── widgets/app_shell.dart                     MODIFY — add reading tab (conditionally)

test/
└── features/reading/
    ├── domain/entities/
    │   └── reading_passage_test.dart              CREATE
    ├── data/sources/
    │   └── reading_passage_source_test.dart       CREATE
    └── domain/use_cases/
        └── generate_reading_passage_use_case_test.dart  CREATE
```

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | [Domain entities](tasks/plan7-task-01.md) | `ReadingPassage`, `BilingualSentence` with JSON serialization |
| 02 | [ReadingPassageSource + UseCase](tasks/plan7-task-02.md) | Gemini prompt → `ReadingPassage`; `GenerateReadingPassageUseCase` |
| 03 | [Provider + DI + Router + AppShell](tasks/plan7-task-03.md) | `ReadingPracticeNotifier`, DI wiring, `/reading` routes, reading tab |
| 04 | [ReadingHomeScreen](tasks/plan7-task-04.md) | Generate button, error states (< 5 words, AI off), loading state |
| 05 | [ReadingSessionScreen](tasks/plan7-task-05.md) | 3-row typing UI: passage + translation + colored typing area |
| 06 | [ReadingResultScreen](tasks/plan7-task-06.md) | Accuracy %, WPM, vocab list, regenerate/home buttons |
