# LexiCore — Global Constraints (Plan 4)

Copy these into every task brief so subagents don't need to read the full plan.

- Flutter SDK: >=3.22.0 · Dart SDK: >=3.4.0
- Target platforms: iOS, Android only
- State management: Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- Navigation: GoRouter only — no `Navigator.push` for screen transitions; `Navigator.pop` OK for dialogs/sheets
- All domain entities: immutable, `const` constructors, no public setters; mutation via `copyWith`
- No business logic in widgets — logic lives in use cases or Notifiers
- Unit tests use `mocktail` (NOT mockito) — `class MockX extends Mock implements X {}`
- Working directory: `d:/Flutter/lexi-core`
- Package name: `lexi_core`
- **NEVER store `geminiApiKey` in Firestore** — local (SharedPreferences) only
- Firebase sign-in is entirely opt-in — all features work without it
- Offline-first: Hive is source of truth; Firestore is a mirror
- Firestore writes are best-effort — log failures, never crash the app
- After any `@riverpod` annotation change run: `dart run build_runner build --delete-conflicting-outputs`

## Codebase artifacts (Plans 1–3)

```dart
// lib/features/dictionary/domain/entities/input_type.dart
enum InputType { word, phrase, sentence }

// lib/features/dictionary/domain/entities/app_context.dart
enum AppContext { general, business, technology, travel, foodDrink, health, academic, socialCasual }

// lib/features/dictionary/domain/entities/language.dart
enum Language { english, chinese, korean, japanese }
// each has: String get label

// lib/features/vocabulary/domain/entities/cefr_level.dart
enum CEFRLevel { a1(0), a2(1), b1(2), b2(3), c1(4), c2(5) }
// each has: String get label  → 'A1', 'A2', etc.
// compare by .index for ≤ filter

// lib/features/vocabulary/domain/entities/vocab_record.dart
final class VocabRecord {
  final String id;
  final String headword;
  final InputType inputType;
  final String ipa;
  final String meaning;
  final List<String> examples;
  final String personalNotes;
  final List<String> topicIds;
  final Language targetLanguage;
  final CEFRLevel cefrLevel;
  final AppContext activeContext;
  final DateTime createdAt;
  final DateTime updatedAt;
  // + SM-2 fields, toJson(), fromJson()
}

// lib/features/vocabulary/domain/entities/topic.dart
final class Topic { final String id; final String name; final String emoji; }

// lib/features/dictionary/domain/entities/user_settings_state.dart (Plan 1–3 version)
final class UserSettingsState {
  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  static const defaults = UserSettingsState(...);
  UserSettingsState copyWith({...});
}

// lib/features/dictionary/presentation/providers/user_settings_provider.dart
// @Riverpod(keepAlive: true) class UserSettingsNotifier extends _$UserSettingsNotifier

// lib/core/di/app_providers.dart — existing providers:
// getVocabListUseCaseProvider → GetVocabListUseCase
// updateVocabUseCaseProvider  → UpdateVocabUseCase
// topicsNotifierProvider      → AsyncValue<List<Topic>>
// userSettingsNotifierProvider → UserSettingsState
// vocabRepositoryProvider     → VocabRepository
// practiceSessionNotifierProvider → PracticeSessionState

// lib/core/router/app_router.dart — ShellRoute with /, /vocab, /practice
// lib/core/widgets/app_shell.dart — 3-tab NavigationBar

// Hive boxes open in main.dart: 'vocab_records' + 'topics' (both Box<String>)
// VocabRecord.toJson() / fromJson() already implemented
```

## Riverpod code generation pattern

Every `@riverpod` annotated file needs a corresponding `.g.dart` generated file.
After any annotation change run: `dart run build_runner build --delete-conflicting-outputs`

## SharedPreferences keys (Plan 4)

| Key | Type | Maps to |
|-----|------|---------|
| `'target_language'` | `String` | `Language.name` |
| `'active_context'` | `String` | `AppContext.name` |
| `'ai_enabled'` | `bool` | `aiEnabled` |
| `'target_cefr_level'` | `String?` | `CEFRLevel.name` or absent = null |
| `'gemini_api_key'` | `String` | local only — NEVER synced to Firestore |

## Firestore schema (Plan 4)

```
users/{uid}/
  vocab_records/{recordId}   ← VocabRecord.toJson()
  topics/{topicId}           ← Topic.toJson()
  settings                   ← single doc: targetLanguage, activeContext, aiEnabled, targetCefrLevel
                               (geminiApiKey is NEVER written here)
```
