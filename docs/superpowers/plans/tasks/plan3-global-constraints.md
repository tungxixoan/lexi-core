# LexiCore — Global Constraints (Plan 3)

Copy these into every task brief so subagents don't need to read the full plan.

- Flutter SDK: >=3.22.0 · Dart SDK: >=3.4.0
- Target platforms: iOS, Android only
- State management: Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- Navigation: GoRouter only — no `Navigator.push` for screen transitions; `Navigator.pop` OK for dialogs/sheets
- All domain entities: immutable, `const` constructors, no public setters; mutation via `copyWith`
- No business logic in widgets — logic lives in use cases or AsyncNotifiers
- Gemini model: `gemini-2.5-flash`, `responseMimeType: 'application/json'`
- `aiEnabled: false` by default — if `!aiEnabled`, skip Gemini and return `FlashcardExercise` immediately
- Unit tests use `mocktail` (NOT mockito) — `class MockX extends Mock implements X {}`
- Working directory: `d:/Flutter/lexi-core`
- Package name: `lexi_core`
- NEVER commit API keys

## Plan 1+2 artifacts already in codebase

```dart
// lib/features/dictionary/domain/entities/input_type.dart
enum InputType { word, phrase, sentence }

// lib/features/dictionary/domain/entities/app_context.dart
enum AppContext { general, business, technology, travel, foodDrink, health, academic, socialCasual }

// lib/features/dictionary/domain/entities/language.dart
enum Language { english, chinese, korean, japanese }
// each has: String get label

// lib/features/vocabulary/domain/entities/cefr_level.dart
enum CEFRLevel { a1, a2, b1, b2, c1, c2 }
// each has: String get label  → 'A1', 'A2', etc.

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
  final DateTime? nextReviewAt;
  final int sm2Repetitions;    // default 0
  final double sm2EaseFactor;  // default 2.5
  final int sm2Interval;       // default 1 (days)
  VocabRecord copyWith({..., DateTime? updatedAt, DateTime? nextReviewAt,
    int? sm2Repetitions, double? sm2EaseFactor, int? sm2Interval});
}

// lib/features/vocabulary/domain/entities/topic.dart
final class Topic { final String id; final String name; final String emoji; }

// lib/core/di/app_providers.dart (Plan 1+2 providers)
// getVocabListUseCaseProvider → GetVocabListUseCase
// updateVocabUseCaseProvider  → UpdateVocabUseCase
// topicsNotifierProvider      → AsyncValue<List<Topic>>
// userSettingsNotifierProvider → UserSettingsState { aiEnabled, geminiApiKey, targetLanguage }
// vocabRepositoryProvider     → VocabRepository

// lib/features/dictionary/data/sources/gemini_dictionary_source.dart
// abstract interface class GenerativeModelClient {
//   Future<GenerateContentResponse> generateContent(Iterable<Content> prompt);
// }
```

## Plan 3 entities (created Task 01)

```dart
// lib/features/practice/domain/entities/exercise.dart
sealed class Exercise { final VocabRecord vocabRecord; }
final class FlashcardExercise extends Exercise { ... }
final class MultipleChoiceExercise extends Exercise {
  final String question;
  final List<String> options; // 4 items
  final int correctIndex;     // 0-3
}
final class FillInBlankExercise extends Exercise {
  final String sentence; // contains '___'
  final String answer;   // lowercase
}
final class TranslationExercise extends Exercise {
  final String prompt;
  final String answer;
}

// lib/features/practice/domain/entities/exercise_result.dart
final class ExerciseResult {
  final String vocabRecordId;
  final int quality;    // 5 = correct, 1 = incorrect
  final bool isCorrect;
}
final class SessionConfig { final List<VocabRecord> words; }
final class SessionResult {
  final List<ExerciseResult> results;
  final List<VocabRecord> words;
  int get correctCount;
  int get totalCount;
}
```

## Riverpod code generation pattern

Every `@riverpod` annotated file needs a corresponding `.g.dart` generated file.
After adding new providers, run: `dart run build_runner build --delete-conflicting-outputs`
