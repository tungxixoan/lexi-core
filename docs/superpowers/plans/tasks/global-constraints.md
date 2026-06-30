# LexiCore — Global Constraints (Plan 1)

Copy these into every task brief so subagents don't need to read the full plan.

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
- Working directory: `d:/Flutter/lexi-core`
