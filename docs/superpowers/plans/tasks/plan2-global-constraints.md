# LexiCore — Global Constraints (Plan 2)

Copy these into every task brief so subagents don't need to read the full plan.

- Flutter SDK: >=3.22.0 · Dart SDK: >=3.4.0
- Target platforms: iOS, Android only
- State management: Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- Navigation: GoRouter only — no `Navigator.push`
- All domain entities: immutable, `const` constructors, no public setters; mutation via `copyWith`
- No business logic in widgets — logic lives in use cases or AsyncNotifiers
- Hive storage: `Box<String>` with `jsonEncode/jsonDecode` — NO Hive code generation (no `@HiveType`, no `hive_generator`)
- Topic constraint: each VocabRecord max **2** topic tags
- Sentences (`InputType.sentence`) are **never** saved to VocabBank
- Predefined 20 topics: cannot be deleted; deleting a custom topic auto-moves its words to topic id `'other'`
- Gemini model: `gemini-2.5-flash`
- Working directory: `d:/Flutter/lexi-core`
- Package name: `lexi_core`

## Plan 1 artifacts already in codebase

These types exist and subagents can import them:

```dart
// lib/features/dictionary/domain/entities/input_type.dart
enum InputType { word, phrase, sentence }

// lib/features/dictionary/domain/entities/app_context.dart
enum AppContext { general, business, technology, travel, foodDrink, health, academic, socialCasual }
// each has: String get label, String get emoji

// lib/features/dictionary/domain/entities/language.dart
enum Language { english, chinese, korean, japanese }
// each has: String get label

// lib/features/dictionary/domain/entities/lookup_result.dart
sealed class LookupResult {}
final class WordPhraseResult extends LookupResult {
  final String headword;
  final InputType inputType;
  final String ipa;
  final String meaning;
  final List<String> examples;
  final List<String> suggestedTopics;
}
final class SentenceResult extends LookupResult { ... }

// lib/features/dictionary/presentation/providers/user_settings_provider.dart
// userSettingsNotifierProvider → UserSettingsState
// UserSettingsState: targetLanguage, activeContext, aiEnabled, geminiApiKey

// lib/services/tts_service.dart
// ttsServiceProvider → TtsService
// TtsService.speak(String text, Language language)
```

## Riverpod code generation pattern

Every `@riverpod` annotated file needs a corresponding `.g.dart` generated file.
After adding new providers, run: `dart run build_runner build --delete-conflicting-outputs`
