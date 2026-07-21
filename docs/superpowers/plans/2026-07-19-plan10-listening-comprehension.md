# LexiCore Plan 10 — "Nghe hiểu" (TOEIC-style Listening Comprehension)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build "Nghe hiểu" — the second card on the "Luyện nghe" hub, currently a disabled "Sắp ra mắt" placeholder. AI generates a short two-speaker conversation or one-speaker talk (chosen randomly), the user listens via `TtsService` with per-turn seek controls (⏮/▶⏸/⏭/🔁, no scrub bar), then answers 3 TOEIC-style multiple-choice questions (main idea / detail / implied meaning — never fill-in-blank) about it, all at once, with unlimited free replay and no scoring penalty.

**Architecture:** New files inside the existing `lib/features/listening/` module (added by Plan 9), following the exact same layering: `ListeningPassageSource` calls the shared `AiClientFactory` (mirrors `DictationSource`/`ReadingPassageSource`), `ListeningComprehensionNotifier` (Riverpod, mirrors `DictationPracticeNotifier`) holds session state including which turn is selected and the 3 selected answers, and three screens (home/session/result) replace stub-free — the hub screen already exists (Plan 9) and only needs its second card enabled. `TtsService` gains an optional `pitch` parameter so conversation speakers sound distinguishable, fully backward-compatible with every existing caller.

**Tech Stack:** `AiClientFactory`/`GenerativeModelClient` (existing, provider-agnostic), Riverpod 2.x `@riverpod`, GoRouter, `uuid`, `flutter_tts` (via existing `TtsService`, extended with pitch)

**BASE commit:** `<SET_AT_EXECUTION_START>`
**Progress ledger:** `.superpowers/sdd/progress.md`

**Spec:** [2026-07-19-listening-practice-design.md](../superpowers/specs/2026-07-19-listening-practice-design.md) §4, §5

## Global Constraints

(see `docs/superpowers/plans/tasks/plan10-global-constraints.md`)

---

## File Map

```text
lib/
├── features/
│   ├── listening/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── listening_passage.dart                CREATE — ListeningKind, ListeningTurn,
│   │   │   │                                                        ListeningQuestion, ListeningPassage
│   │   │   └── use_cases/
│   │   │       └── generate_listening_passage_use_case.dart CREATE
│   │   ├── data/
│   │   │   └── sources/
│   │   │       └── listening_passage_source.dart          CREATE — AI prompt + JSON parse
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── listening_comprehension_provider.dart  CREATE — ListeningSessionState,
│   │       │                                                        ComprehensionSessionResult,
│   │       │                                                        ListeningComprehensionNotifier
│   │       └── screens/
│   │           ├── listening_home_screen.dart              MODIFY — enable the "Nghe hiểu" card
│   │           ├── comprehension_home_screen.dart           CREATE
│   │           ├── comprehension_session_screen.dart        CREATE
│   │           └── comprehension_result_screen.dart         CREATE
├── services/
│   └── tts_service.dart                                    MODIFY — add optional `pitch` param
├── core/
│   ├── di/app_providers.dart                               MODIFY — add ListeningPassageSource + use case DI
│   └── router/app_router.dart                              MODIFY — add /listening/comprehension routes

test/
├── services/tts_service_test.dart                                          CREATE
└── features/listening/
    ├── domain/entities/listening_passage_test.dart                        CREATE
    ├── data/sources/listening_passage_source_test.dart                    CREATE
    ├── domain/use_cases/generate_listening_passage_use_case_test.dart      CREATE
    ├── presentation/providers/listening_comprehension_provider_test.dart   CREATE
    └── presentation/screens/
        ├── listening_home_screen_test.dart                                 MODIFY (or CREATE if absent)
        ├── comprehension_home_screen_test.dart                             CREATE
        ├── comprehension_session_screen_test.dart                         CREATE
        └── comprehension_result_screen_test.dart                          CREATE
```

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | [ListeningPassage entities](tasks/plan10-task-01.md) | `ListeningKind`, `ListeningTurn`, `ListeningQuestion`, `ListeningPassage` |
| 02 | [TtsService pitch support](tasks/plan10-task-02.md) | `TtsService.speak(text, language, {pitch})`, backward-compatible |
| 03 | [ListeningPassageSource + UseCase](tasks/plan10-task-03.md) | AI prompt → `ListeningPassage`; `GenerateListeningPassageUseCase` |
| 04 | [Provider + DI + Router + Enable Hub Card](tasks/plan10-task-04.md) | `ListeningComprehensionNotifier`, DI wiring, `/listening/comprehension` routes, hub card enabled, stub screens |
| 05 | [ComprehensionHomeScreen](tasks/plan10-task-05.md) | Ngôn ngữ/Chủ đề(AppContext)/Cấp độ filters, AI-disabled error state, generate flow |
| 06 | [ComprehensionSessionScreen](tasks/plan10-task-06.md) | Per-turn player controls (⏮/▶⏸/⏭/🔁), 3 questions, submit gating |
| 07 | [ComprehensionResultScreen](tasks/plan10-task-07.md) | Score X/3, per-question breakdown, transcript, regenerate/home buttons |
| 08 | [Update README](tasks/plan10-task-08.md) | Document "Nghe hiểu" in Tính năng, Kiến trúc, Roadmap |
