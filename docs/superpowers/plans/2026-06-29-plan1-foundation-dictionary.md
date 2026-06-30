# LexiCore — Plan 1: Foundation + Dictionary Lookup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Task files split:** Individual task briefs live in `docs/superpowers/plans/tasks/task-{01..15}.md`.
> Navigation index + progress ledger: `docs/superpowers/plans/tasks/INDEX.md`
> **Do NOT read this full plan file per-task** — read `INDEX.md` first, then dispatch each subagent with only their task file to save tokens.

**Goal:** Set up the Flutter project with Clean Architecture and deliver a working dictionary lookup feature — word/phrase/sentence detection, Gemini Flash AI, Free Dictionary fallback (English only), IPA, TTS pronunciation, active context selector, and Discover button.

**Architecture:** Clean Architecture (Domain / Data / Presentation). Repository pattern abstracts AI-on vs AI-off routing. Riverpod 2.x with code generation manages all state. GoRouter handles navigation. TTS is an abstract interface for testability.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod 2.x + riverpod_generator, GoRouter, google_generative_ai, http, flutter_tts, mockito

**This is Plan 1 of 4:**

- Plan 1 (this): Foundation + Dictionary Lookup
- Plan 2: Vocabulary Bank + Topic System
- Plan 3: Spaced Repetition + Auto Exercises
- Plan 4: Firebase Sync + Settings Screen + Level Auto-Adjust

## Global Constraints

- Flutter SDK: >=3.22.0 · Dart SDK: >=3.4.0
- Target platforms: iOS, Android only
- State management: Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- Navigation: GoRouter only — no `Navigator.push`
- All domain entities: immutable, `const` constructors, no public setters
- No business logic in widgets — logic lives in use cases or AsyncNotifiers
- Gemini model: `gemini-2.5-flash`
- Free Dictionary API: `https://api.dictionaryapi.dev/api/v2/entries/en/{word}`
- Native language: Vietnamese (fixed in v1)
- Default target language: English

---

## File Map

```text
lib/
├── main.dart
├── core/
│   ├── di/app_providers.dart                  Riverpod DI wiring
│   ├── router/app_router.dart                 GoRouter config
│   ├── theme/app_theme.dart                   ThemeData light + dark
│   └── utils/input_detector.dart             Heuristic classifier
├── services/
│   └── tts_service.dart                       Abstract TtsService + FlutterTtsService impl
└── features/dictionary/
    ├── domain/
    │   ├── entities/
    │   │   ├── input_type.dart                enum InputType
    │   │   ├── app_context.dart               enum AppContext
    │   │   ├── language.dart                  enum Language
    │   │   ├── lookup_result.dart             sealed class LookupResult
    │   │   └── user_settings_state.dart       immutable value object
    │   ├── repositories/
    │   │   └── dictionary_repository.dart     abstract interface
    │   └── use_cases/
    │       └── lookup_use_case.dart
    ├── data/
    │   ├── sources/
    │   │   ├── free_dictionary_source.dart    HTTP client for freedictionary API
    │   │   └── gemini_dictionary_source.dart  Gemini Flash client
    │   └── repositories/
    │       └── dictionary_repository_impl.dart
    └── presentation/
        ├── providers/
        │   ├── user_settings_provider.dart    settings state + notifier
        │   └── lookup_provider.dart           AsyncNotifier for lookup
        ├── screens/
        │   └── lookup_screen.dart
        └── widgets/
            ├── context_selector_widget.dart
            ├── search_bar_widget.dart
            ├── word_result_widget.dart
            └── sentence_result_widget.dart

test/
├── core/utils/input_detector_test.dart
├── features/dictionary/
│   ├── domain/use_cases/lookup_use_case_test.dart
│   ├── data/
│   │   ├── sources/free_dictionary_source_test.dart
│   │   └── repositories/dictionary_repository_impl_test.dart
│   └── presentation/providers/lookup_provider_test.dart
```

---

## Tasks (summary — full briefs in task files)

| # | Task | Output |
| --- | --- | --- |
| 01 | Flutter Project Setup | pubspec.yaml, folder structure |
| 02 | Domain Entities | InputType, AppContext, Language, LookupResult, UserSettingsState |
| 03 | Input Type Detector | `InputDetector.detect(String) → InputType` |
| 04 | TTS Service | `TtsService` abstract + `FlutterTtsService` |
| 05 | Repository Interface + Exception | `DictionaryRepository`, `DictionaryException` |
| 06 | Free Dictionary Source | `FreeDictionarySource.lookup(word)` |
| 07 | Gemini Dictionary Source | `GeminiDictionarySource.lookup(...)`, `.discoverWord(...)` |
| 08 | Repository Implementation | `DictionaryRepositoryImpl` — AI routing logic |
| 09 | Lookup Use Case | `LookupUseCase.execute(...)` |
| 10 | Riverpod Providers | `userSettingsNotifierProvider`, `lookupNotifierProvider`, DI wiring |
| 11 | App Shell | theme, router, main.dart, placeholder LookupScreen |
| 12 | Context Selector Widget | `ContextSelectorWidget` |
| 13 | Search Bar Widget | `SearchBarWidget` + Discover button |
| 14 | Result Widgets | `WordResultWidget`, `SentenceResultWidget` |
| 15 | Lookup Screen Assembly | Full `LookupScreen`, `flutter run` verification |

**Full task briefs:** `docs/superpowers/plans/tasks/task-{01..15}.md`
**Progress ledger:** `docs/superpowers/plans/tasks/INDEX.md`
