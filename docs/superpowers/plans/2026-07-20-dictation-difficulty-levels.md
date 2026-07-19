# Nghe chép Difficulty Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 selectable difficulty levels to the already-shipped "Nghe chép" (Dictation) feature — Dễ (fill 2 single-word blanks), Trung bình (fill 1 multi-word blank spanning ~35% of the sentence), Khó (unchanged full blind transcription) — chosen per session, defaulting to Khó.

**Architecture:** A new pure `SelectDictationBlanksUseCase` computes blank word-indices from the existing `DictationItem.target` string (no AI/entity changes). `DictationSessionState`/`DictationSessionResult` gain optional `difficulty`/`blanks`/`blankAnswers` fields (all defaulting to today's Khó-only shape, so Khó's existing code path is untouched). The session and result screens branch on `difficulty` to render either the existing single-`TextField`/full-diff UI (Khó) or a new cloze (fill-in-the-blank) UI (Dễ/Trung bình) built from the same segment list.

**Tech Stack:** Riverpod 2.x `@riverpod`, `dart:math` `Random` (blank selection), existing Flutter widgets (no new packages)

**BASE commit:** `<SET_AT_EXECUTION_START>`
**Progress ledger:** `.superpowers/sdd/progress.md`

**Spec:** [2026-07-20-dictation-difficulty-levels-design.md](../superpowers/specs/2026-07-20-dictation-difficulty-levels-design.md)

## Global Constraints

(see `docs/superpowers/plans/tasks/dictation-difficulty-global-constraints.md`)

---

## File Map

```text
lib/
├── features/
│   └── listening/
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── dictation_difficulty.dart       CREATE — DictationDifficulty enum
│       │   │   └── blank_span.dart                 CREATE — BlankSpan value object
│       │   └── use_cases/
│       │       └── select_dictation_blanks_use_case.dart  CREATE — pure blank-selection algorithm
│       └── presentation/
│           ├── providers/
│           │   └── dictation_practice_provider.dart       MODIFY — difficulty/blanks/blankAnswers,
│           │                                                        updateBlankAnswer(), blockAccuracy
│           └── screens/
│               ├── dictation_home_screen.dart              MODIFY — "Mức độ" FilterTile
│               ├── dictation_session_screen.dart           MODIFY — cloze input UI for Dễ/Trung bình
│               └── dictation_result_screen.dart            MODIFY — cloze read-only colored result

test/
└── features/listening/
    ├── domain/
    │   ├── entities/
    │   │   ├── dictation_difficulty_test.dart                      CREATE
    │   │   └── blank_span_test.dart                                CREATE
    │   └── use_cases/
    │       └── select_dictation_blanks_use_case_test.dart          CREATE
    └── presentation/
        ├── providers/dictation_practice_provider_test.dart          MODIFY
        └── screens/
            ├── dictation_home_screen_test.dart                      MODIFY
            ├── dictation_session_screen_test.dart                   MODIFY
            └── dictation_result_screen_test.dart                    MODIFY

README.md                                                            MODIFY (Task 06)
```

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | [DictationDifficulty + BlankSpan + SelectDictationBlanksUseCase](tasks/dictation-difficulty-task-01.md) | Enum, value object, pure blank-selection algorithm |
| 02 | [Extend DictationPracticeNotifier](tasks/dictation-difficulty-task-02.md) | `difficulty`/`blanks`/`blankAnswers` fields, `updateBlankAnswer()`, `blockAccuracy` scoring — all additive |
| 03 | [DictationHomeScreen: Mức độ picker](tasks/dictation-difficulty-task-03.md) | Difficulty `FilterTile`, threaded into `generate()` |
| 04 | [DictationSessionScreen: cloze input UI](tasks/dictation-difficulty-task-04.md) | Inline fill-in-the-blank rendering for Dễ/Trung bình |
| 05 | [DictationResultScreen: cloze result view](tasks/dictation-difficulty-task-05.md) | Read-only colored blank rendering for Dễ/Trung bình |
| 06 | [Update README](tasks/dictation-difficulty-task-06.md) | Document the 3 difficulty levels |
