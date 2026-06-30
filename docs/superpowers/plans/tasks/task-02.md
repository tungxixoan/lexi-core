# Task 2: Domain Entities

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 1 (project exists, pubspec installed)

## Global Constraints
- All domain entities: immutable, `const` constructors, no public setters
- No business logic in entities

## What This Task Delivers
Five pure Dart entity files. No tests needed (pure enums/value objects with no logic).

## Files to Create
- `lib/features/dictionary/domain/entities/input_type.dart`
- `lib/features/dictionary/domain/entities/app_context.dart`
- `lib/features/dictionary/domain/entities/language.dart`
- `lib/features/dictionary/domain/entities/lookup_result.dart`
- `lib/features/dictionary/domain/entities/user_settings_state.dart`

## Produces (used by Tasks 3–15)
- `enum InputType { word, phrase, sentence }`
- `enum AppContext` with `.label` and `.emoji` getters
- `enum Language` with `.code`, `.ttsLocale`, `.label`, `.requiresAi` getters
- `sealed class LookupResult` → `WordPhraseResult` | `SentenceResult`
- `final class UserSettingsState` with `copyWith` and `defaults` constant

## Steps

- [ ] **Step 1: Create input_type.dart**

```dart
// lib/features/dictionary/domain/entities/input_type.dart
enum InputType { word, phrase, sentence }
```

- [ ] **Step 2: Create app_context.dart**

```dart
// lib/features/dictionary/domain/entities/app_context.dart
enum AppContext {
  general,
  business,
  technology,
  travel,
  foodAndDrink,
  health,
  academic,
  socialCasual;

  String get label => switch (this) {
        AppContext.general => 'General',
        AppContext.business => 'Business',
        AppContext.technology => 'Technology',
        AppContext.travel => 'Travel',
        AppContext.foodAndDrink => 'Food & Drink',
        AppContext.health => 'Health',
        AppContext.academic => 'Academic',
        AppContext.socialCasual => 'Social/Casual',
      };

  String get emoji => switch (this) {
        AppContext.general => '🌐',
        AppContext.business => '💼',
        AppContext.technology => '💻',
        AppContext.travel => '✈️',
        AppContext.foodAndDrink => '🍜',
        AppContext.health => '🏥',
        AppContext.academic => '📚',
        AppContext.socialCasual => '💬',
      };
}
```

- [ ] **Step 3: Create language.dart**

```dart
// lib/features/dictionary/domain/entities/language.dart
enum Language {
  vietnamese,
  english,
  chinese,
  korean,
  japanese;

  String get code => switch (this) {
        Language.vietnamese => 'vi',
        Language.english => 'en',
        Language.chinese => 'zh',
        Language.korean => 'ko',
        Language.japanese => 'ja',
      };

  String get ttsLocale => switch (this) {
        Language.vietnamese => 'vi-VN',
        Language.english => 'en-US',
        Language.chinese => 'zh-CN',
        Language.korean => 'ko-KR',
        Language.japanese => 'ja-JP',
      };

  String get label => switch (this) {
        Language.vietnamese => 'Tiếng Việt',
        Language.english => 'English',
        Language.chinese => '中文',
        Language.korean => '한국어',
        Language.japanese => '日本語',
      };

  bool get requiresAi => this != Language.english;
}
```

- [ ] **Step 4: Create lookup_result.dart**

```dart
// lib/features/dictionary/domain/entities/lookup_result.dart
import 'input_type.dart';

sealed class LookupResult {
  const LookupResult();
}

final class WordPhraseResult extends LookupResult {
  const WordPhraseResult({
    required this.headword,
    required this.inputType,
    required this.ipa,
    required this.meaning,
    required this.examples,
    required this.suggestedTopics,
  });

  final String headword;
  final InputType inputType; // word or phrase only — never sentence
  final String ipa;
  final String meaning;
  final List<String> examples;
  final List<String> suggestedTopics;
}

final class SentenceResult extends LookupResult {
  const SentenceResult({
    required this.original,
    required this.translation,
  });

  final String original;
  final String translation;
}
```

- [ ] **Step 5: Create user_settings_state.dart**

```dart
// lib/features/dictionary/domain/entities/user_settings_state.dart
import 'app_context.dart';
import 'language.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.geminiApiKey,
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    String? geminiApiKey,
  }) =>
      UserSettingsState(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        activeContext: activeContext ?? this.activeContext,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      );

  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    activeContext: AppContext.general,
    aiEnabled: true,
    geminiApiKey: '',
  );
}
```

- [ ] **Step 6: Verify compilation**

```bash
flutter analyze lib/features/dictionary/domain/entities/
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dictionary/domain/entities/
git commit -m "feat: add domain entities (InputType, AppContext, Language, LookupResult, UserSettingsState)"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: N/A
Concerns: (if any)
