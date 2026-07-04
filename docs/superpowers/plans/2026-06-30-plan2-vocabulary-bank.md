# LexiCore Plan 2 — Vocabulary Bank + Topic System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.
> Individual task briefs are in `docs/superpowers/plans/tasks/plan2-task-{01..11}.md`.
> Global constraints: `docs/superpowers/plans/tasks/plan2-global-constraints.md`.

**Goal:** Let users save looked-up words/phrases to a personal Vocabulary Bank, organize them by topic (20 predefined + custom), and view/edit entries — using Hive for offline-first local storage.

**Architecture:** New `vocabulary` feature module following Clean Architecture (same pattern as `dictionary`). VocabRecords stored in Hive as JSON strings (no code generation). Topics seeded on first run. Bottom navigation added via GoRouter ShellRoute to expose Vocab Bank alongside Dictionary.

**Tech Stack:** hive 2.2.3, hive_flutter 1.1.0, uuid 4.5.1 (added to existing Flutter/Riverpod/GoRouter stack)

**BASE commit:** `1f036a4`
**Progress ledger:** `.superpowers/sdd/progress.md`

## Global Constraints

- Flutter SDK >=3.22.0, Dart >=3.4.0
- Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- Navigation: GoRouter only — no `Navigator.push`
- All domain entities: immutable, `const` constructors, no public setters; mutation via `copyWith`
- Hive storage: `Box<String>` with `jsonEncode/jsonDecode` — no Hive code generation
- Topic constraint: each VocabRecord max **2** topic tags
- Sentences are **never** saved to VocabBank (only word/phrase InputType)
- Predefined 20 topics: cannot be deleted; words in a deleted custom topic → auto-reassigned to `'other'`

---

## File Map

```text
lib/
├── core/
│   ├── di/app_providers.dart           MODIFY — add vocab DI providers
│   ├── router/app_router.dart          MODIFY — add ShellRoute + vocab routes
│   └── widgets/app_shell.dart          CREATE — NavigationBar wrapper
├── features/
│   ├── dictionary/
│   │   └── presentation/widgets/
│   │       ├── word_result_widget.dart MODIFY — add Save button
│   │       └── save_vocab_sheet.dart   CREATE — bottom sheet for save/edit
│   └── vocabulary/
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── cefr_level.dart     CREATE
│       │   │   ├── vocab_record.dart   CREATE
│       │   │   └── topic.dart          CREATE
│       │   ├── repositories/
│       │   │   └── vocab_repository.dart   CREATE
│       │   └── use_cases/
│       │       ├── save_vocab_use_case.dart
│       │       ├── get_vocab_list_use_case.dart
│       │       ├── update_vocab_use_case.dart
│       │       ├── delete_vocab_use_case.dart
│       │       ├── get_topics_use_case.dart
│       │       ├── add_topic_use_case.dart
│       │       └── delete_topic_use_case.dart
│       ├── data/repositories/
│       │   └── vocab_repository_impl.dart  CREATE
│       └── presentation/
│           ├── providers/
│           │   ├── vocab_bank_provider.dart   CREATE
│           │   └── topics_provider.dart        CREATE
│           └── screens/
│               ├── vocab_bank_screen.dart      CREATE
│               └── vocab_detail_screen.dart    CREATE

test/
└── features/vocabulary/
    └── domain/use_cases/
        └── vocab_use_cases_test.dart   CREATE
```

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | [Hive + UUID setup](tasks/plan2-task-01.md) | pubspec deps, async Hive init in main.dart |
| 02 | [Domain entities](tasks/plan2-task-02.md) | CEFRLevel, VocabRecord, Topic (with predefined list) |
| 03 | [VocabRepository interface](tasks/plan2-task-03.md) | abstract interface + VocabException |
| 04 | [VocabRepositoryImpl](tasks/plan2-task-04.md) | Hive JSON storage + predefined topic seeding |
| 05 | [Use cases](tasks/plan2-task-05.md) | 7 use cases — SaveVocab (≤2 topics), Get, Update, Delete, GetTopics, AddTopic, DeleteTopic |
| 06 | [Riverpod providers + DI](tasks/plan2-task-06.md) | VocabBankNotifier, TopicsNotifier, app_providers wiring |
| 07 | [Save button + SaveVocabSheet](tasks/plan2-task-07.md) | Save/Saved toggle in WordResultWidget; bottom sheet |
| 08 | [App shell + bottom nav](tasks/plan2-task-08.md) | ShellRoute in GoRouter; AppShell NavigationBar |
| 09 | [VocabBankScreen](tasks/plan2-task-09.md) | List with topic filter chips, search, empty state |
| 10 | [VocabDetailScreen](tasks/plan2-task-10.md) | View + edit meaning/examples/notes/topics; delete |
| 11 | [VocabBank lookup cache](tasks/plan2-task-11.md) | lookup_provider checks VocabBank before calling API |
