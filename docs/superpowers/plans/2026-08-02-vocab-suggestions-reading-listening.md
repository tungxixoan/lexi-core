# Vocab Suggestions for Reading/Listening Results Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After finishing a Reading or Comprehension (listening) practice session, show a "Gợi ý từ mới" (new word suggestions) section on the result screen — reusing Word Radar's exact AI-suggestion pipeline (find already-known headwords in the text, then ask the AI to suggest new ones excluding those) and its tap-to-save / dismiss / save-all UI.

**Architecture:** A new use case `GetVocabSuggestionsForTextUseCase` composes the two existing Word Radar use cases (`FindKnownHeadwordsUseCase` + `GenerateWordSuggestionsUseCase`) into a single call. The suggestion-card UI currently inlined in `WordRadarScreen` is extracted into a standalone widget `VocabSuggestionsSection` so it can be reused verbatim by `ReadingResultScreen` and `ComprehensionResultScreen`, which each call the new use case once in `initState` (fire-and-forget, like the existing `_recordPracticeSession`/`_updateSm2` calls) using their already-generated passage/transcript text.

**Tech Stack:** Flutter, Riverpod (`riverpod_generator` codegen), `flutter_test` + `mocktail`.

## Global Constraints

- Riverpod providers are defined with `@riverpod` annotations in `lib/core/di/app_providers.dart` and require `dart run build_runner build --delete-conflicting-outputs` after any change to regenerate `app_providers.g.dart`.
- Follow TDD: write the failing test first, watch it fail, then implement.
- Vietnamese UI strings must match existing ones exactly where reused (e.g. `'Gợi ý từ mới'`, `'Lưu tất cả'`, `'Không có gợi ý mới.'`, `'Bỏ qua gợi ý này'`) — these are asserted on by existing tests that must keep passing unchanged.
- Do not change `WordRadarNotifier` (`lib/features/word_radar/presentation/providers/word_radar_provider.dart`) — it needs `knownRecords` separately for text highlighting, so it keeps its own two-call sequence instead of using the new combined use case.

---

## File Structure

- **Create** `lib/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart` — combines find-known + generate-suggestions into one call.
- **Create** `test/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case_test.dart`
- **Modify** `lib/core/di/app_providers.dart` — register `getVocabSuggestionsForTextUseCaseProvider`.
- **Create** `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart` — the extracted suggestion-cards widget (save/dismiss/save-all).
- **Create** `test/features/word_radar/presentation/widgets/vocab_suggestions_section_test.dart`
- **Modify** `lib/features/word_radar/presentation/screens/word_radar_screen.dart` — delegate to the new widget, remove the now-duplicated code.
- **Modify** `lib/features/reading/presentation/screens/reading_result_screen.dart` — load + show suggestions for `result.passage.fullText`.
- **Modify** `test/features/reading/presentation/screens/reading_result_screen_test.dart`
- **Modify** `lib/features/listening/presentation/screens/comprehension_result_screen.dart` — load + show suggestions for the joined transcript text.
- **Modify** `test/features/listening/presentation/screens/comprehension_result_screen_test.dart`

---

### Task 1: `GetVocabSuggestionsForTextUseCase`

**Files:**
- Create: `lib/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart`
- Test: `test/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case_test.dart`
- Modify: `lib/core/di/app_providers.dart`

**Interfaces:**
- Consumes: `FindKnownHeadwordsUseCase.execute({required String text, required Language language}) -> Future<List<VocabRecord>>` (existing, `lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart`); `GenerateWordSuggestionsUseCase.execute({required String text, required Language targetLanguage, required CEFRLevel? targetCefrLevel, required List<String> knownHeadwords}) -> Future<WordRadarAiResult>` (existing, `lib/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart`).
- Produces: `GetVocabSuggestionsForTextUseCase.execute({required String text, required Language targetLanguage, required CEFRLevel? targetCefrLevel}) -> Future<WordRadarAiResult>`; provider `getVocabSuggestionsForTextUseCaseProvider`.

- [ ] **Step 1: Write the failing test**

Create `test/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';

class MockFindKnownHeadwordsUseCase extends Mock
    implements FindKnownHeadwordsUseCase {}

class MockGenerateWordSuggestionsUseCase extends Mock
    implements GenerateWordSuggestionsUseCase {}

VocabRecord _record(String headword) => VocabRecord(
      id: headword,
      headword: headword,
      inputType: InputType.word,
      ipa: '',
      meaning: 'meaning of $headword',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late MockFindKnownHeadwordsUseCase mockFindKnown;
  late MockGenerateWordSuggestionsUseCase mockGenerate;
  late GetVocabSuggestionsForTextUseCase useCase;

  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  setUp(() {
    mockFindKnown = MockFindKnownHeadwordsUseCase();
    mockGenerate = MockGenerateWordSuggestionsUseCase();
    useCase = GetVocabSuggestionsForTextUseCase(mockFindKnown, mockGenerate);
  });

  test(
      'finds known headwords in the text first, then excludes them when generating suggestions',
      () async {
    when(() => mockFindKnown.execute(
          text: any(named: 'text'),
          language: any(named: 'language'),
        )).thenAnswer((_) async => [_record('cat'), _record('dog')]);
    const expected = WordRadarAiResult(translation: '', suggestions: []);
    when(() => mockGenerate.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
          knownHeadwords: any(named: 'knownHeadwords'),
        )).thenAnswer((_) async => expected);

    final result = await useCase.execute(
      text: 'The cat chased the dog.',
      targetLanguage: Language.english,
      targetCefrLevel: CEFRLevel.b1,
    );

    expect(result, same(expected));
    verify(() => mockFindKnown.execute(
          text: 'The cat chased the dog.',
          language: Language.english,
        )).called(1);
    verify(() => mockGenerate.execute(
          text: 'The cat chased the dog.',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
          knownHeadwords: ['cat', 'dog'],
        )).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case_test.dart`
Expected: FAIL to compile — `get_vocab_suggestions_for_text_use_case.dart` does not exist yet (`Target of URI doesn't exist`).

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'find_known_headwords_use_case.dart';
import 'generate_word_suggestions_use_case.dart';
import '../entities/word_radar_ai_result.dart';

class GetVocabSuggestionsForTextUseCase {
  const GetVocabSuggestionsForTextUseCase(this._findKnown, this._generate);
  final FindKnownHeadwordsUseCase _findKnown;
  final GenerateWordSuggestionsUseCase _generate;

  Future<WordRadarAiResult> execute({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
  }) async {
    final known = await _findKnown.execute(text: text, language: targetLanguage);
    return _generate.execute(
      text: text,
      targetLanguage: targetLanguage,
      targetCefrLevel: targetCefrLevel,
      knownHeadwords: known.map((r) => r.headword).toList(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Register the provider**

In `lib/core/di/app_providers.dart`, add the import near the other `word_radar` imports (after line 43, `generate_word_suggestions_use_case.dart`):

```dart
import '../../features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';
```

Then add the provider right after the existing `generateWordSuggestionsUseCase` provider (after line 195, `GenerateWordSuggestionsUseCase(ref.watch(wordRadarSourceProvider));`):

```dart

@riverpod
GetVocabSuggestionsForTextUseCase getVocabSuggestionsForTextUseCase(
        GetVocabSuggestionsForTextUseCaseRef ref) =>
    GetVocabSuggestionsForTextUseCase(
      ref.watch(findKnownHeadwordsUseCaseProvider),
      ref.watch(generateWordSuggestionsUseCaseProvider),
    );
```

- [ ] **Step 6: Regenerate Riverpod codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes without errors; `lib/core/di/app_providers.g.dart` now contains `getVocabSuggestionsForTextUseCaseProvider`.

- [ ] **Step 7: Verify everything still compiles and passes**

Run: `flutter analyze lib/features/word_radar lib/core/di test/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case_test.dart`
Expected: `No issues found!`

Run: `flutter test test/features/word_radar/domain/use_cases/`
Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add lib/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart test/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case_test.dart lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart
git commit -m "feat(word-radar): add GetVocabSuggestionsForTextUseCase

Combines find-known-headwords + generate-suggestions into one call,
for reuse by the Reading/Comprehension result screens."
```

---

### Task 2: Extract `VocabSuggestionsSection` out of `WordRadarScreen`

**Files:**
- Create: `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart`
- Test: `test/features/word_radar/presentation/widgets/vocab_suggestions_section_test.dart`
- Modify: `lib/features/word_radar/presentation/screens/word_radar_screen.dart`

**Interfaces:**
- Consumes: `WordPhraseResult` (`lib/features/dictionary/domain/entities/lookup_result.dart`, existing), `SaveVocabSheet` (`lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart`, existing), `vocabBankNotifierProvider`, `topicsNotifierProvider`, `userSettingsNotifierProvider` (all existing).
- Produces: `VocabSuggestionsSection({required List<WordPhraseResult> suggestions})` — a `ConsumerStatefulWidget` importable from `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart`. Renders the "Gợi ý từ mới" header, "Lưu tất cả" button, and one tap-to-save/dismiss card per suggestion — self-contained, no callbacks needed from the parent.

- [ ] **Step 1: Write the failing test**

Create `test/features/word_radar/presentation/widgets/vocab_suggestions_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/word_radar/presentation/widgets/vocab_suggestions_section.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async => false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async => null;

  @override
  Future<List<Topic>> getTopics() async => [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

const _suggestion = WordPhraseResult(
  headword: 'ubiquitous',
  inputType: InputType.word,
  ipa: '/juːˈbɪkwɪtəs/',
  meaning: 'có mặt khắp nơi',
  examples: [],
  suggestedTopics: [],
);

Future<Widget> _buildSection(List<WordPhraseResult> suggestions) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults),
      ),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(const [])),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: VocabSuggestionsSection(suggestions: suggestions),
      ),
    ),
  );
}

void main() {
  testWidgets('shows "Không có gợi ý mới." when there are no suggestions', (tester) async {
    await tester.pumpWidget(await _buildSection(const []));
    await tester.pumpAndSettle();
    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });

  testWidgets('tapping a suggestion card opens the save sheet', (tester) async {
    await tester.pumpWidget(await _buildSection(const [_suggestion]));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsOneWidget);
    await tester.tap(find.text('ubiquitous'));
    await tester.pumpAndSettle();

    expect(find.text('Save "ubiquitous"'), findsOneWidget);
  });

  testWidgets('tapping the dismiss icon removes a suggestion from the list', (tester) async {
    await tester.pumpWidget(await _buildSection(const [_suggestion]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsNothing);
    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });

  testWidgets('Lưu tất cả saves every suggestion and shows a checkmark', (tester) async {
    await tester.pumpWidget(await _buildSection(const [_suggestion]));
    await tester.pumpAndSettle();

    expect(find.text('Lưu tất cả'), findsOneWidget);
    await tester.tap(find.text('Lưu tất cả'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Lưu tất cả'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/word_radar/presentation/widgets/vocab_suggestions_section_test.dart`
Expected: FAIL to compile — `vocab_suggestions_section.dart` does not exist yet.

- [ ] **Step 3: Write the widget (moved verbatim from `word_radar_screen.dart`)**

Create `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../dictionary/presentation/widgets/save_vocab_sheet.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../../vocabulary/presentation/providers/vocab_bank_provider.dart';

/// Tap-to-save cards for AI-suggested new vocabulary, with a "Lưu tất cả"
/// bulk-save button and a per-card dismiss (X) button. Shared by Word Radar
/// and by any screen offering the same "suggest new words from this text"
/// flow (Reading and Comprehension result screens).
class VocabSuggestionsSection extends ConsumerStatefulWidget {
  const VocabSuggestionsSection({super.key, required this.suggestions});
  final List<WordPhraseResult> suggestions;

  @override
  ConsumerState<VocabSuggestionsSection> createState() =>
      _VocabSuggestionsSectionState();
}

class _VocabSuggestionsSectionState extends ConsumerState<VocabSuggestionsSection> {
  final Set<String> _savedHeadwords = {};
  final Set<String> _dismissedHeadwords = {};

  Future<void> _openSaveSheet(WordPhraseResult suggestion) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaveVocabSheet(result: suggestion),
    );
    if (mounted && saved == true) {
      setState(() => _savedHeadwords.add(suggestion.headword));
    }
  }

  /// Best-effort bulk save: builds each record the same way [SaveVocabSheet]
  /// would with its defaults (no per-item editing UI), skipping any that
  /// fail (e.g. a duplicate headword already in the Vocab Bank) so one bad
  /// item doesn't block the rest of the batch.
  Future<void> _saveAll(List<WordPhraseResult> suggestions) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final topics = await ref.read(topicsNotifierProvider.future);
    final toSave = suggestions
        .where((s) =>
            !_savedHeadwords.contains(s.headword) &&
            !_dismissedHeadwords.contains(s.headword))
        .toList();

    var savedCount = 0;
    for (final s in toSave) {
      final topicIds = <String>[];
      for (final suggestedTopic in s.suggestedTopics) {
        final match =
            topics.where((t) => t.name.toLowerCase() == suggestedTopic.toLowerCase());
        if (match.isNotEmpty && topicIds.length < 2) {
          topicIds.add(match.first.id);
        }
      }
      final record = VocabRecord(
        id: const Uuid().v4(),
        headword: s.headword,
        inputType: s.inputType,
        ipa: s.ipa,
        meaning: s.meaning,
        examples: s.examples,
        personalNotes: '',
        topicIds: topicIds,
        targetLanguage: settings.targetLanguage,
        cefrLevel: s.cefrLevel ?? CEFRLevel.b1,
        activeContext: settings.activeContext,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        definition: s.definition,
        synonyms: s.synonyms,
      );
      try {
        await ref.read(vocabBankNotifierProvider.notifier).save(record);
        savedCount++;
        if (mounted) setState(() => _savedHeadwords.add(s.headword));
      } catch (_) {
        // Likely a duplicate headword — skip it, keep saving the rest.
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu $savedCount/${toSave.length} từ.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleSuggestions = widget.suggestions
        .where((s) => !_dismissedHeadwords.contains(s.headword))
        .toList();
    final hasUnsaved =
        visibleSuggestions.any((s) => !_savedHeadwords.contains(s.headword));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Gợi ý từ mới', style: theme.textTheme.labelLarge),
            const Spacer(),
            if (hasUnsaved)
              TextButton.icon(
                onPressed: () => _saveAll(visibleSuggestions),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Lưu tất cả'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (visibleSuggestions.isEmpty)
          const Text('Không có gợi ý mới.')
        else
          Column(
            children: visibleSuggestions.map((s) {
              final isSaved = _savedHeadwords.contains(s.headword);
              return Card(
                child: ListTile(
                  onTap: isSaved ? null : () => _openSaveSheet(s),
                  title: Text(s.headword),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${s.ipa}  •  ${s.meaning}'),
                      if (s.cefrLevel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Chip(
                            label: Text(s.cefrLevel!.label),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  trailing: isSaved
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Bỏ qua gợi ý này',
                          onPressed: () =>
                              setState(() => _dismissedHeadwords.add(s.headword)),
                        ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/word_radar/presentation/widgets/vocab_suggestions_section_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Refactor `WordRadarScreen` to delegate to the new widget**

In `lib/features/word_radar/presentation/screens/word_radar_screen.dart`:

Replace the import block (lines 1–13) with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/word_radar_ai_result.dart';
import '../providers/word_radar_provider.dart';
import '../widgets/vocab_suggestions_section.dart';
```

Delete these two fields from `_WordRadarScreenState`:

```dart
  final Set<String> _savedHeadwords = {};
  final Set<String> _dismissedHeadwords = {};
```

Delete these two methods entirely: `_openSaveSheet` and `_saveAll` (the full bodies currently duplicated into `VocabSuggestionsSection` in Step 3 above).

Replace `_buildAiResult` with:

```dart
  Widget _buildAiResult(
    WordRadarAiResult result,
    WordRadarState radarState,
    ThemeData theme,
  ) {
    final knownMeanings = (radarState.knownRecords ?? const [])
        .map((r) => r.meaning)
        .where((m) => m.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.translation.isNotEmpty) ...[
          Text('Bản dịch', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _HighlightedText(
            text: result.translation,
            highlights: knownMeanings,
          ),
          const SizedBox(height: 24),
        ],
        VocabSuggestionsSection(suggestions: result.suggestions),
      ],
    );
  }
```

- [ ] **Step 6: Run the full Word Radar test suite to confirm no regressions**

Run: `flutter test test/features/word_radar/`
Expected: all pass — `word_radar_screen_test.dart`'s save/dismiss/save-all/CEFR-chip tests must still pass unchanged, since the widget tree they inspect (via `find.text`/`find.byIcon`) is unchanged, only its code location moved.

- [ ] **Step 7: Analyze for unused imports**

Run: `flutter analyze lib/features/word_radar test/features/word_radar`
Expected: `No issues found!` (confirms no leftover unused imports in `word_radar_screen.dart` after removing `uuid`, `lookup_result.dart`, `user_settings_provider.dart`, `save_vocab_sheet.dart`, `cefr_level.dart`, `vocab_record.dart`, `topics_provider.dart`, `vocab_bank_provider.dart` — remove any the analyzer flags as unused that aren't listed above, since the exact set depends on what else the file happens to reference).

- [ ] **Step 8: Commit**

```bash
git add lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart test/features/word_radar/presentation/widgets/vocab_suggestions_section_test.dart lib/features/word_radar/presentation/screens/word_radar_screen.dart
git commit -m "refactor(word-radar): extract VocabSuggestionsSection widget

Pure code move — same save/dismiss/save-all behavior, now reusable by
the Reading/Comprehension result screens."
```

---

### Task 3: Wire suggestions into `ReadingResultScreen`

**Files:**
- Modify: `lib/features/reading/presentation/screens/reading_result_screen.dart`
- Modify: `test/features/reading/presentation/screens/reading_result_screen_test.dart`

**Interfaces:**
- Consumes: `getVocabSuggestionsForTextUseCaseProvider` (Task 1), `VocabSuggestionsSection` (Task 2), `ReadingPassage.fullText` (existing getter, `lib/features/reading/domain/entities/reading_passage.dart`), `ReadingPassage.level`/`ReadingPassage.targetLanguage` (existing fields).
- Produces: n/a (leaf screen).

- [ ] **Step 1: Write the failing tests**

In `test/features/reading/presentation/screens/reading_result_screen_test.dart`, add these imports alongside the existing ones:

```dart
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';
```

Add this mock class next to `MockStatsService`:

```dart
class MockGetVocabSuggestionsForTextUseCase extends Mock
    implements GetVocabSuggestionsForTextUseCase {}
```

Add a `setUpAll` at the top of `main()` (mocktail needs fallback values for the enum params used with `any()`):

```dart
void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  // ...existing tests...
```

Add these two tests at the end of `main()`, before the final closing `}`:

```dart
  testWidgets(
      'loads new-word suggestions for the full passage text and shows them',
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

    await tester.pumpWidget(_buildResult(
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions),
      ],
    ));
    await tester.pumpAndSettle();

    verify(() => mockSuggestions.execute(
          text: 'Hello world.',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });

  testWidgets('does not crash when loading suggestions fails', (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenThrow(Exception('AI unavailable'));

    await tester.pumpWidget(_buildResult(
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sinh bài mới'), findsOneWidget); // screen still renders
    expect(find.textContaining('Không tải được gợi ý'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/reading/presentation/screens/reading_result_screen_test.dart`
Expected: FAIL — either a compile error (`getVocabSuggestionsForTextUseCaseProvider` used but the screen never reads it so `overrideWithValue` on an unread provider won't itself fail, but `verify(...)` will report no matching calls) or `find.text('Gợi ý từ mới')` finds nothing.

- [ ] **Step 3: Implement in `ReadingResultScreen`**

In `lib/features/reading/presentation/screens/reading_result_screen.dart`, add the import:

```dart
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
```

Add state and a loader method to `_ReadingResultScreenState`, right after `_recordPracticeSession`:

```dart
  AsyncValue<WordRadarAiResult>? _suggestions;

  Future<void> _loadSuggestions() async {
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

Add the `WordRadarAiResult` import too:

```dart
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
```

Call the loader from `initState`, alongside the existing streak call:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }
```

Add a section builder method:

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

In the `build` method, find this exact block (currently right after `const SizedBox(height: 24),` and right before the `// Action buttons` comment):

```dart
            if (usedRecords.isNotEmpty) ...[
              Text(
                'Từ vựng đã luyện',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: usedRecords.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final record = usedRecords[i];
                    return ListTile(
                      title: Text(record.headword),
                      subtitle: Text(
                        record.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const Spacer(),
```

Replace it with (this keeps the buttons pinned to the bottom in both the empty and non-empty case, the same way the old `Spacer()` did, because the outer `Expanded` still claims all remaining vertical space — it just now wraps a scrollable column instead of only a list):

```dart
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (usedRecords.isNotEmpty) ...[
                      Text('Từ vựng đã luyện', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: usedRecords.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final record = usedRecords[i];
                          return ListTile(
                            title: Text(record.headword),
                            subtitle: Text(
                              record.meaning,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            dense: true,
                          );
                        },
                      ),
                    ],
                    _buildSuggestionsSection(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reading/presentation/screens/reading_result_screen_test.dart`
Expected: PASS (all tests, including the two new ones and the pre-existing ones from earlier work).

- [ ] **Step 5: Run the full reading suite**

Run: `flutter test test/features/reading/`
Expected: all pass.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/reading test/features/reading`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/reading/presentation/screens/reading_result_screen.dart test/features/reading/presentation/screens/reading_result_screen_test.dart
git commit -m "feat(reading): suggest new words from the passage on the result screen

Reuses the Word Radar suggestion pipeline against the full generated
passage text, shown below the practiced-vocab list."
```

---

### Task 4: Wire suggestions into `ComprehensionResultScreen`

**Files:**
- Modify: `lib/features/listening/presentation/screens/comprehension_result_screen.dart`
- Modify: `test/features/listening/presentation/screens/comprehension_result_screen_test.dart`

**Interfaces:**
- Consumes: `getVocabSuggestionsForTextUseCaseProvider` (Task 1), `VocabSuggestionsSection` (Task 2), `ListeningPassage.turns`/`.level`/`.targetLanguage` (existing, `lib/features/listening/domain/entities/listening_passage.dart`).
- Produces: n/a (leaf screen).

- [ ] **Step 1: Write the failing test**

In `test/features/listening/presentation/screens/comprehension_result_screen_test.dart`, add these imports:

```dart
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';
```

Add this mock class next to `MockStatsService`:

```dart
class MockGetVocabSuggestionsForTextUseCase extends Mock
    implements GetVocabSuggestionsForTextUseCase {}
```

Add a `setUpAll` at the top of `main()`:

```dart
void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  // ...existing tests...
```

Add this test at the end of `main()`, before the final closing `}`:

```dart
  testWidgets(
      'loads new-word suggestions for the full transcript text and shows them',
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

    await tester.pumpWidget(_buildResult(
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions),
      ],
    ));
    await tester.pumpAndSettle();

    // _testPassage.turns joined: "Can I help you? I am looking for a jacket."
    verify(() => mockSuggestions.execute(
          text: 'Can I help you? I am looking for a jacket.',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listening/presentation/screens/comprehension_result_screen_test.dart`
Expected: FAIL — `verify(...)` reports no matching calls (the screen doesn't call the use case yet).

- [ ] **Step 3: Implement in `ComprehensionResultScreen`**

In `lib/features/listening/presentation/screens/comprehension_result_screen.dart`, add imports:

```dart
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
```

Add state, a text getter, and a loader method to `_ComprehensionResultScreenState`, right after `_recordPracticeSession`:

```dart
  AsyncValue<WordRadarAiResult>? _suggestions;

  String get _transcriptText => result.passage.turns.map((t) => t.text).join(' ');

  Future<void> _loadSuggestions() async {
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

Call the loader from `initState`, alongside the existing streak call:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }
```

Add a section builder method:

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

Add a call to `_buildSuggestionsSection()` at the end of the existing scrollable `Column`'s children (right after the `...result.passage.turns.map(...)` transcript block, still inside the `Expanded(child: SingleChildScrollView(child: Column(children: [...])))`):

```dart
                    ...result.passage.turns.map(
                      (t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          t.speaker != null ? '${t.speaker}: ${t.text}' : t.text,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    _buildSuggestionsSection(),
                  ],
                ),
              ),
            ),
```

(Only the new `_buildSuggestionsSection(),` line is added — the existing `Expanded(child: SingleChildScrollView(...))` structure here already scrolls, unlike Reading, so no other layout change is needed.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/listening/presentation/screens/comprehension_result_screen_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Run the full listening suite**

Run: `flutter test test/features/listening/`
Expected: all pass.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/listening test/features/listening`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/listening/presentation/screens/comprehension_result_screen.dart test/features/listening/presentation/screens/comprehension_result_screen_test.dart
git commit -m "feat(listening): suggest new words from the transcript on the result screen

Reuses the Word Radar suggestion pipeline against the full turn
transcript, shown below the transcript on the Comprehension result
screen."
```

---

## Final Verification

- [ ] Run the whole suite: `flutter test`
- [ ] Run the whole analyzer: `flutter analyze`
- [ ] Manually confirm (per project convention — type-checking/tests verify correctness, not feature UX): generate a Reading passage, finish typing it, confirm "Gợi ý từ mới" appears on the result screen with real AI suggestions (requires AI enabled + a configured API key); repeat for Nghe hiểu (Comprehension).
