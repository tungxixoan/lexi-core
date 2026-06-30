# LexiCore Plan 1 — Task Index

**Goal:** Foundation + Dictionary Lookup feature
**Total tasks:** 15 (sequential — each depends on the previous)

## Quick Reference

| # | Task | Key output | Test? |
|---|---|---|---|
| [01](task-01.md) | Flutter Project Setup | pubspec, folder structure | N/A |
| [02](task-02.md) | Domain Entities | InputType, AppContext, Language, LookupResult, UserSettingsState | N/A |
| [03](task-03.md) | Input Type Detector | `InputDetector.detect(String) → InputType` | ✅ unit |
| [04](task-04.md) | TTS Service | `TtsService` abstract + `FlutterTtsService` | N/A |
| [05](task-05.md) | Repository Interface + Exception | `DictionaryRepository`, `DictionaryException` | N/A |
| [06](task-06.md) | Free Dictionary Source | `FreeDictionarySource.lookup(word)` | ✅ unit |
| [07](task-07.md) | Gemini Dictionary Source | `GeminiDictionarySource.lookup(...)`, `.discoverWord(...)` | ✅ unit |
| [08](task-08.md) | Repository Implementation | `DictionaryRepositoryImpl` (AI routing logic) | ✅ unit |
| [09](task-09.md) | Lookup Use Case | `LookupUseCase.execute(...)` | ✅ unit |
| [10](task-10.md) | Riverpod Providers | `userSettingsNotifierProvider`, `lookupNotifierProvider`, DI wiring | ✅ unit |
| [11](task-11.md) | App Shell | theme, router, main.dart, placeholder LookupScreen | build |
| [12](task-12.md) | Context Selector Widget | `ContextSelectorWidget` | ✅ widget |
| [13](task-13.md) | Search Bar Widget | `SearchBarWidget` + Discover button | N/A |
| [14](task-14.md) | Result Widgets | `WordResultWidget`, `SentenceResultWidget` | N/A |
| [15](task-15.md) | Lookup Screen Assembly | Full `LookupScreen`, `flutter run` verification | ✅ manual |

## Global Constraints
See [global-constraints.md](global-constraints.md) — copy into every dispatch prompt.

## Dependency Chain
```
01 → 02 → 03 → 04
              ↓
         05 → 06 → 08 → 09 → 10 → 11 → 12 → 13 → 14 → 15
              07 ↗
```

## Controller Notes (for subagent-driven execution)

When dispatching Task N, always include in the prompt:
1. What Task N-1 produced (key interface signatures)
2. The git commit SHA from Task N-1 (for diff generation)
3. Global constraints (from global-constraints.md)

**Key interface hand-offs:**
- After Task 2: entities path = `lib/features/dictionary/domain/entities/`
- After Task 3: `InputDetector.detect(String) → InputType`
- After Task 5: `DictionaryException(String)`, `DictionaryRepository` interface
- After Task 7: `GeminiDictionarySource.withModel(GenerativeModel)` test constructor
- After Task 9: `LookupUseCase(DictionaryRepository)`
- After Task 10: `lookupNotifierProvider`, `userSettingsNotifierProvider`, `ttsServiceProvider`, `geminiDictionarySourceProvider`

## Progress Ledger
(Controller fills this in as tasks complete)

- Task 1: ⬜ pending
- Task 2: ⬜ pending
- Task 3: ⬜ pending
- Task 4: ⬜ pending
- Task 5: ⬜ pending
- Task 6: ⬜ pending
- Task 7: ⬜ pending
- Task 8: ⬜ pending
- Task 9: ⬜ pending
- Task 10: ⬜ pending
- Task 11: ⬜ pending
- Task 12: ⬜ pending
- Task 13: ⬜ pending
- Task 14: ⬜ pending
- Task 15: ⬜ pending
