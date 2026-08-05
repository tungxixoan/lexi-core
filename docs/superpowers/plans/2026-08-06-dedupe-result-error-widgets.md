# Dedupe Result-Screen Suggestions & Home-Screen Error Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate two pieces of verbatim-duplicated UI code (flagged by the TOEIC Part 5/6 final whole-branch review) by extracting each into one shared widget: a private `_ErrorCard` class copy-pasted into 5 home screens, and a suggestions-loading trio (`_suggestions` field + `_recordPracticeSession()`/`_loadSuggestions()`/`_buildSuggestionsSection()`) copy-pasted into 4 result screens.

**Architecture:** Pure extraction, no behavior change. `AiDisabledCard` (new, `lib/core/widgets/`) replaces the private `_ErrorCard` in all 5 home screens. `ResultSuggestionsSection` (new, `lib/features/word_radar/presentation/widgets/`) replaces the suggestions trio in all 4 result screens, wrapping the existing `VocabSuggestionsSection` and `getVocabSuggestionsForTextUseCaseProvider` it already depended on. Every touched screen's existing test suite must pass unmodified — that's the proof the extraction is behavior-preserving.

**Tech Stack:** Flutter, Riverpod (`ConsumerStatefulWidget`), `flutter_test` + `mocktail`.

**Spec:** [2026-08-05-dedupe-result-error-widgets-design.md](../specs/2026-08-05-dedupe-result-error-widgets-design.md)

## Global Constraints

- No behavior changes anywhere in this plan — every screen must render and behave identically before and after. The safety net is each touched screen's pre-existing test suite passing without modification.
- `_recordPracticeSession()` stays inline per result screen — not extracted (too small, count argument differs per screen).
- `dictation_result_screen.dart` is untouched — it has no suggestions section.
- Run `flutter analyze` and `flutter test` (scoped per-file/per-directory while iterating; full-suite once at the end of Task 4) — must be clean before committing.

---

## File Structure

```text
lib/
├── core/widgets/
│   └── ai_disabled_card.dart                                CREATE
├── features/word_radar/presentation/widgets/
│   └── result_suggestions_section.dart                       CREATE
├── features/reading/presentation/screens/
│   ├── reading_home_screen.dart                               MODIFY — use AiDisabledCard
│   ├── part5_home_screen.dart                                 MODIFY — use AiDisabledCard
│   ├── part6_home_screen.dart                                 MODIFY — use AiDisabledCard
│   ├── reading_result_screen.dart                              MODIFY — use ResultSuggestionsSection
│   ├── part5_result_screen.dart                                MODIFY — use ResultSuggestionsSection
│   └── part6_result_screen.dart                                MODIFY — use ResultSuggestionsSection
└── features/listening/presentation/screens/
    ├── comprehension_home_screen.dart                          MODIFY — use AiDisabledCard
    ├── dictation_home_screen.dart                              MODIFY — use AiDisabledCard
    └── comprehension_result_screen.dart                        MODIFY — use ResultSuggestionsSection

test/
├── core/widgets/ai_disabled_card_test.dart                    CREATE
└── features/word_radar/presentation/widgets/result_suggestions_section_test.dart  CREATE
```

---

### Task 1: `AiDisabledCard`

**Files:**
- Create: `lib/core/widgets/ai_disabled_card.dart`
- Test: `test/core/widgets/ai_disabled_card_test.dart`

**Interfaces:**
- Produces: `AiDisabledCard({required String message})` — consumed by Task 2.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/ai_disabled_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/widgets/ai_disabled_card.dart';

void main() {
  testWidgets('renders the given message inside a Card', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiDisabledCard(message: 'Cần bật AI để dùng.')),
      ),
    );
    expect(find.text('Cần bật AI để dùng.'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/ai_disabled_card_test.dart`
Expected: FAIL — `ai_disabled_card.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/widgets/ai_disabled_card.dart`:

```dart
import 'package:flutter/material.dart';

/// A Card in the theme's error colors, used across home screens to explain
/// why a generate action is unavailable (AI disabled, not enough saved
/// words, etc).
class AiDisabledCard extends StatelessWidget {
  const AiDisabledCard({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/ai_disabled_card_test.dart`
Expected: PASS — 1/1 test.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/core/widgets/ai_disabled_card.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/ai_disabled_card.dart test/core/widgets/ai_disabled_card_test.dart
git commit -m "feat(core): add AiDisabledCard shared widget"
```

---

### Task 2: Migrate 5 home screens to `AiDisabledCard`

**Files:**
- Modify: `lib/features/reading/presentation/screens/reading_home_screen.dart`
- Modify: `lib/features/reading/presentation/screens/part5_home_screen.dart`
- Modify: `lib/features/reading/presentation/screens/part6_home_screen.dart`
- Modify: `lib/features/listening/presentation/screens/comprehension_home_screen.dart`
- Modify: `lib/features/listening/presentation/screens/dictation_home_screen.dart`

**Interfaces:**
- Consumes: `AiDisabledCard` (Task 1).

Each of the 5 files currently ends with an identical private `_ErrorCard extends StatelessWidget` class (same shape as `AiDisabledCard`, just private) as the very last thing in the file, and has 1 or 2 call sites earlier in the file. For each file: add the import, replace every `_ErrorCard(` call site with `AiDisabledCard(`, then delete the entire trailing `_ErrorCard` class (from its `class _ErrorCard extends StatelessWidget {` line to the file's closing `}`).

- [ ] **Step 1: `reading_home_screen.dart`**

Add this import alongside the existing `core/widgets/` imports:

```dart
import '../../../../core/widgets/ai_disabled_card.dart';
```

Replace both call sites — change:

```dart
            if (!settings.aiEnabled)
              _ErrorCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

to:

```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

and change:

```dart
            else if (words.length < _minVocabWords)
              _ErrorCard(
                message:
                    'Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Vocab Bank. '
                    'Hiện có ${words.length} từ.',
              )
```

to:

```dart
            else if (words.length < _minVocabWords)
              AiDisabledCard(
                message:
                    'Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Vocab Bank. '
                    'Hiện có ${words.length} từ.',
              )
```

Delete the trailing class (the file's last 19 lines, starting at `class _ErrorCard extends StatelessWidget {`):

```dart
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
```

(delete this whole block — nothing replaces it, the file just ends after the previous class now).

- [ ] **Step 2: `part5_home_screen.dart`**

Add import alongside the existing `core/widgets/` imports:

```dart
import '../../../../core/widgets/ai_disabled_card.dart';
```

Replace the one call site — change:

```dart
            if (!settings.aiEnabled)
              _ErrorCard(
                message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

to:

```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

Delete the trailing class:

```dart
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      ),
    );
  }
}
```

- [ ] **Step 3: `part6_home_screen.dart`**

Add import alongside the existing `core/widgets/` imports:

```dart
import '../../../../core/widgets/ai_disabled_card.dart';
```

Replace the one call site — change:

```dart
            if (!settings.aiEnabled)
              _ErrorCard(
                message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

to:

```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

Delete the trailing class:

```dart
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      ),
    );
  }
}
```

- [ ] **Step 4: `comprehension_home_screen.dart`**

Add import alongside the existing `core/widgets/` imports:

```dart
import '../../../../core/widgets/ai_disabled_card.dart';
```

Replace the one call site — change:

```dart
            if (!settings.aiEnabled)
              _ErrorCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

to:

```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

Delete the trailing class (same shape as Step 1's).

- [ ] **Step 5: `dictation_home_screen.dart`**

Add import alongside the existing `core/widgets/` imports:

```dart
import '../../../../core/widgets/ai_disabled_card.dart';
```

Replace both call sites — change:

```dart
            if (!settings.aiEnabled)
              _ErrorCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

to:

```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
```

and change:

```dart
            else if (words.length < _minVocabWords)
              _ErrorCard(
                message:
                    'Hãy lưu ít nhất 2 từ khớp với bộ lọc trên vào Vocab Bank. '
                    'Hiện có ${words.length} từ.',
```

to:

```dart
            else if (words.length < _minVocabWords)
              AiDisabledCard(
                message:
                    'Hãy lưu ít nhất 2 từ khớp với bộ lọc trên vào Vocab Bank. '
                    'Hiện có ${words.length} từ.',
```

(keep whatever closing follows on the next lines unchanged). Delete the trailing class (same shape as Step 1's).

- [ ] **Step 6: Run each touched screen's existing test suite — must pass unmodified**

```bash
flutter test test/features/reading/presentation/screens/reading_home_screen_test.dart
flutter test test/features/reading/presentation/screens/part5_home_screen_test.dart
flutter test test/features/reading/presentation/screens/part6_home_screen_test.dart
flutter test test/features/listening/presentation/screens/comprehension_home_screen_test.dart
flutter test test/features/listening/presentation/screens/dictation_home_screen_test.dart
```

Expected: all pass, with zero test-file edits. If any assertion needs to change, stop — that means the extraction changed behavior, which is out of scope for this plan.

- [ ] **Step 7: Analyze**

```bash
flutter analyze lib/features/reading/presentation/screens/reading_home_screen.dart lib/features/reading/presentation/screens/part5_home_screen.dart lib/features/reading/presentation/screens/part6_home_screen.dart lib/features/listening/presentation/screens/comprehension_home_screen.dart lib/features/listening/presentation/screens/dictation_home_screen.dart
```

Expected: no issues (aside from any pre-existing, unrelated `deprecated_member_use` infos already known from earlier work — none are expected in these particular files, but if one appears, confirm via `git diff` that this task's edit didn't introduce it before treating it as pre-existing).

- [ ] **Step 8: Commit**

```bash
git add lib/features/reading/presentation/screens/reading_home_screen.dart \
        lib/features/reading/presentation/screens/part5_home_screen.dart \
        lib/features/reading/presentation/screens/part6_home_screen.dart \
        lib/features/listening/presentation/screens/comprehension_home_screen.dart \
        lib/features/listening/presentation/screens/dictation_home_screen.dart
git commit -m "refactor: migrate 5 home screens to shared AiDisabledCard"
```

---

### Task 3: `ResultSuggestionsSection`

**Files:**
- Create: `lib/features/word_radar/presentation/widgets/result_suggestions_section.dart`
- Test: `test/features/word_radar/presentation/widgets/result_suggestions_section_test.dart`

**Interfaces:**
- Consumes: `getVocabSuggestionsForTextUseCaseProvider` (existing, `lib/core/di/app_providers.dart`), `userSettingsNotifierProvider` (existing), `VocabSuggestionsSection` (existing, sibling file in the same directory), `WordRadarAiResult` (existing).
- Produces: `ResultSuggestionsSection({required String text, required Language targetLanguage, required CEFRLevel? targetCefrLevel})` — consumed by Task 4.

- [ ] **Step 1: Write the failing tests**

Create `test/features/word_radar/presentation/widgets/result_suggestions_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';
import 'package:lexi_core/features/word_radar/presentation/widgets/result_suggestions_section.dart';

class MockGetVocabSuggestionsForTextUseCase extends Mock
    implements GetVocabSuggestionsForTextUseCase {}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

Future<Widget> _buildSection({
  required bool aiEnabled,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults.copyWith(aiEnabled: aiEnabled)),
      ),
      ...extraOverrides,
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: ResultSuggestionsSection(
          text: 'some passage text',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  testWidgets('does not call the suggestions use case when AI is disabled', (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    await tester.pumpWidget(await _buildSection(
      aiEnabled: false,
      extraOverrides: [getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions)],
    ));
    await tester.pumpAndSettle();

    verifyNever(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        ));
    expect(find.text('Gợi ý từ mới'), findsNothing);
  });

  testWidgets('loads suggestions with the given text/language/level and renders them',
      (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenAnswer((_) async => const WordRadarAiResult(
          translation: '',
          suggestions: [
            WordPhraseResult(
              headword: 'ubiquitous',
              inputType: InputType.word,
              ipa: '/juːˈbɪkwɪtəs/',
              meaning: 'có mặt khắp nơi',
              examples: [],
              suggestedTopics: [],
            ),
          ],
        ));

    await tester.pumpWidget(await _buildSection(
      aiEnabled: true,
      extraOverrides: [getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions)],
    ));
    await tester.pumpAndSettle();

    verify(() => mockSuggestions.execute(
          text: 'some passage text',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });

  testWidgets('shows an error message with a retry button on failure', (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenThrow(Exception('network error'));

    await tester.pumpWidget(await _buildSection(
      aiEnabled: true,
      extraOverrides: [getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions)],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không tải được gợi ý từ mới'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('tapping Thử lại retries the use case call', (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    var callCount = 0;
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) throw Exception('network error');
      return const WordRadarAiResult(translation: '', suggestions: []);
    });

    await tester.pumpWidget(await _buildSection(
      aiEnabled: true,
      extraOverrides: [getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(callCount, 2);
    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/word_radar/presentation/widgets/result_suggestions_section_test.dart`
Expected: FAIL — `result_suggestions_section.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/word_radar/presentation/widgets/result_suggestions_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/word_radar_ai_result.dart';
import 'vocab_suggestions_section.dart';

/// Loads and renders AI-suggested new vocabulary for [text]. Shared by every
/// practice result screen (Đọc & gõ, Nghe hiểu, Part 5, Part 6) instead of
/// each duplicating its own loading/error/retry state machine around
/// [VocabSuggestionsSection].
class ResultSuggestionsSection extends ConsumerStatefulWidget {
  const ResultSuggestionsSection({
    super.key,
    required this.text,
    required this.targetLanguage,
    required this.targetCefrLevel,
  });

  final String text;
  final Language targetLanguage;
  final CEFRLevel? targetCefrLevel;

  @override
  ConsumerState<ResultSuggestionsSection> createState() => _ResultSuggestionsSectionState();
}

class _ResultSuggestionsSectionState extends ConsumerState<ResultSuggestionsSection> {
  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final result = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: widget.text,
            targetLanguage: widget.targetLanguage,
            targetCefrLevel: widget.targetCefrLevel,
          ),
    );
    if (mounted) setState(() => _suggestions = result);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/word_radar/presentation/widgets/result_suggestions_section_test.dart`
Expected: PASS — 4/4 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/word_radar/presentation/widgets/result_suggestions_section.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/word_radar/presentation/widgets/result_suggestions_section.dart test/features/word_radar/presentation/widgets/result_suggestions_section_test.dart
git commit -m "feat(word-radar): add ResultSuggestionsSection shared widget"
```

---

### Task 4: Migrate 4 result screens to `ResultSuggestionsSection` + final verification

**Files:**
- Modify: `lib/features/reading/presentation/screens/reading_result_screen.dart`
- Modify: `lib/features/reading/presentation/screens/part5_result_screen.dart`
- Modify: `lib/features/reading/presentation/screens/part6_result_screen.dart`
- Modify: `lib/features/listening/presentation/screens/comprehension_result_screen.dart`

**Interfaces:**
- Consumes: `ResultSuggestionsSection` (Task 3).

For each file: remove the `AsyncValue<WordRadarAiResult>? _suggestions;` field, the `_loadSuggestions()` method, the `_buildSuggestionsSection()` method, and the `_loadSuggestions();` call inside `initState()`'s post-frame callback (keep the `_recordPracticeSession();` call there). Replace the `_buildSuggestionsSection()` call site in `build()` with `ResultSuggestionsSection(text: ..., targetLanguage: ..., targetCefrLevel: ...)` using the per-screen values below. Drop the now-unused `WordRadarAiResult`/`VocabSuggestionsSection`/`userSettingsNotifierProvider` imports if nothing else in the file uses them (check each file — `userSettingsNotifierProvider` is only used by `_loadSuggestions` in all 4 files, so it becomes unused in all 4; `getVocabSuggestionsForTextUseCaseProvider` likewise; `WordRadarAiResult` and `VocabSuggestionsSection` likewise).

Add this import to each file (path depth is the same in all 4 — `presentation/screens/` → `word_radar/presentation/widgets/`):

```dart
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
```

- [ ] **Step 1: `reading_result_screen.dart`**

Change the imports block from:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
import '../providers/reading_practice_provider.dart';
```

to:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../providers/reading_practice_provider.dart';
```

Change:

```dart
  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(result.passage.vocabIds.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  Future<void> _loadSuggestions() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final aiResult = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: result.passage.fullText,
            targetLanguage: result.passage.targetLanguage,
            targetCefrLevel: result.passage.level,
          ),
    );
    if (mounted) setState(() => _suggestions = aiResult);
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(result.passage.vocabIds.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }
```

Change the call site:

```dart
                    _buildSuggestionsSection(),
```

to:

```dart
                    ResultSuggestionsSection(
                      text: result.passage.fullText,
                      targetLanguage: result.passage.targetLanguage,
                      targetCefrLevel: result.passage.level,
                    ),
```

Delete the whole `_buildSuggestionsSection()` method:

```dart
  Widget _buildSuggestionsSection() {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(
              onPressed: _loadSuggestions,
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }
```

- [ ] **Step 2: `part5_result_screen.dart`**

Change the imports block from:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
import '../../domain/entities/part5_question.dart';
import '../providers/part5_practice_provider.dart';
```

to:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../../domain/entities/part5_question.dart';
import '../providers/part5_practice_provider.dart';
```

Change:

```dart
  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(result.set.questions.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _questionsText => result.set.questions.map((q) => q.sentenceWithBlank).join(' ');

  Future<void> _loadSuggestions() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final aiResult = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: _questionsText,
            targetLanguage: result.set.targetLanguage,
            targetCefrLevel: null,
          ),
    );
    if (mounted) setState(() => _suggestions = aiResult);
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(result.set.questions.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _questionsText => result.set.questions.map((q) => q.sentenceWithBlank).join(' ');
```

Change the call site:

```dart
                    _buildSuggestionsSection(),
```

to:

```dart
                    ResultSuggestionsSection(
                      text: _questionsText,
                      targetLanguage: result.set.targetLanguage,
                      targetCefrLevel: null,
                    ),
```

Delete the whole `_buildSuggestionsSection()` method:

```dart
  Widget _buildSuggestionsSection() {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(onPressed: _loadSuggestions, child: const Text('Thử lại')),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }
```

- [ ] **Step 3: `part6_result_screen.dart`**

Change the imports block from:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
import '../../domain/entities/part6_passage.dart';
import '../providers/part6_practice_provider.dart';
```

to:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../../domain/entities/part6_passage.dart';
import '../providers/part6_practice_provider.dart';
```

Change:

```dart
  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }

  int get _totalQuestions =>
      result.set.passages.fold(0, (sum, p) => sum + p.questions.length);

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(_totalQuestions);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _passagesText => result.set.passages.map((p) => p.passageText).join(' ');

  Future<void> _loadSuggestions() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final aiResult = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: _passagesText,
            targetLanguage: result.set.targetLanguage,
            targetCefrLevel: null,
          ),
    );
    if (mounted) setState(() => _suggestions = aiResult);
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  int get _totalQuestions =>
      result.set.passages.fold(0, (sum, p) => sum + p.questions.length);

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(_totalQuestions);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _passagesText => result.set.passages.map((p) => p.passageText).join(' ');
```

Change the call site:

```dart
                    _buildSuggestionsSection(),
```

to:

```dart
                    ResultSuggestionsSection(
                      text: _passagesText,
                      targetLanguage: result.set.targetLanguage,
                      targetCefrLevel: null,
                    ),
```

Delete the whole `_buildSuggestionsSection()` method:

```dart
  Widget _buildSuggestionsSection() {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(onPressed: _loadSuggestions, child: const Text('Thử lại')),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }
```

- [ ] **Step 4: `comprehension_result_screen.dart`**

Change the imports block from:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
import '../../domain/entities/listening_passage.dart';
import '../providers/listening_comprehension_provider.dart';
```

to:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../../domain/entities/listening_passage.dart';
import '../providers/listening_comprehension_provider.dart';
```

Change:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(result.passage.questions.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  AsyncValue<WordRadarAiResult>? _suggestions;

  String get _transcriptText => result.passage.turns.map((t) => t.text).join(' ');

  Future<void> _loadSuggestions() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final aiResult = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: _transcriptText,
            targetLanguage: result.passage.targetLanguage,
            targetCefrLevel: result.passage.level,
          ),
    );
    if (mounted) setState(() => _suggestions = aiResult);
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(result.passage.questions.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _transcriptText => result.passage.turns.map((t) => t.text).join(' ');
```

Change the call site:

```dart
                    _buildSuggestionsSection(),
```

to:

```dart
                    ResultSuggestionsSection(
                      text: _transcriptText,
                      targetLanguage: result.passage.targetLanguage,
                      targetCefrLevel: result.passage.level,
                    ),
```

Delete the whole `_buildSuggestionsSection()` method:

```dart
  Widget _buildSuggestionsSection() {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(
              onPressed: _loadSuggestions,
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }
```

- [ ] **Step 5: Run each touched screen's existing test suite — must pass unmodified**

```bash
flutter test test/features/reading/presentation/screens/reading_result_screen_test.dart
flutter test test/features/reading/presentation/screens/part5_result_screen_test.dart
flutter test test/features/reading/presentation/screens/part6_result_screen_test.dart
flutter test test/features/listening/presentation/screens/comprehension_result_screen_test.dart
```

Expected: all pass, with zero test-file edits. If any assertion needs to change, stop — the extraction changed behavior, out of scope for this plan.

- [ ] **Step 6: Analyze the 4 changed files**

```bash
flutter analyze lib/features/reading/presentation/screens/reading_result_screen.dart lib/features/reading/presentation/screens/part5_result_screen.dart lib/features/reading/presentation/screens/part6_result_screen.dart lib/features/listening/presentation/screens/comprehension_result_screen.dart
```

Expected: no issues, and specifically no `unused_import` warnings — confirm `WordRadarAiResult`, `VocabSuggestionsSection`, and `userSettingsNotifierProvider`/`getVocabSuggestionsForTextUseCaseProvider` imports were actually removable in each file (they should be, since `_loadSuggestions`/`_buildSuggestionsSection` were their only users) rather than leaving a stale unused import.

- [ ] **Step 7: Full-project analyze, regenerate codegen, full test suite, web build**

```bash
flutter analyze lib/
dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/
flutter test
flutter build web --release
```

Expected: no analyzer issues beyond the pre-existing, unrelated `RadioListTile`/`RadioGroup` deprecation infos already known from earlier work; full suite green; web build succeeds.

- [ ] **Step 8: Commit**

```bash
git add lib/features/reading/presentation/screens/reading_result_screen.dart \
        lib/features/reading/presentation/screens/part5_result_screen.dart \
        lib/features/reading/presentation/screens/part6_result_screen.dart \
        lib/features/listening/presentation/screens/comprehension_result_screen.dart
git commit -m "refactor: migrate 4 result screens to shared ResultSuggestionsSection"
```
