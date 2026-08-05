# Dedupe Result-Screen Suggestions & Home-Screen Error Card — Design Spec

**Date:** 2026-08-05
**Status:** Approved

## Goal

Eliminate two pieces of verbatim-duplicated UI code flagged by the final whole-branch review of the TOEIC Part 5/6 feature (`.superpowers/sdd/progress.md`), before they compound further with a future Part 7:

1. A private `_ErrorCard` class, byte-identical, copy-pasted into 5 home screens.
2. A `_suggestions` field + `_recordPracticeSession()`/`_loadSuggestions()`/`_buildSuggestionsSection()` trio, byte-identical apart from the input text/language/level, copy-pasted into 4 result screens.

No behavior changes — this is a pure extraction. Every screen must render and behave identically before and after.

## Scope

**In scope:**
- `lib/core/widgets/` gains a shared error-card widget.
- `lib/features/word_radar/presentation/widgets/` gains a shared result-suggestions widget.
- 5 home screens updated to use the shared error card: `reading_home_screen.dart`, `part5_home_screen.dart`, `part6_home_screen.dart`, `lib/features/listening/presentation/screens/comprehension_home_screen.dart`, `lib/features/listening/presentation/screens/dictation_home_screen.dart`.
- 4 result screens updated to use the shared suggestions widget: `reading_result_screen.dart`, `part5_result_screen.dart`, `part6_result_screen.dart`, `lib/features/listening/presentation/screens/comprehension_result_screen.dart`.

**Out of scope:**
- `_recordPracticeSession()` stays inline per result screen (5-7 lines, the question/word count argument differs per screen, too small to be worth an abstraction — YAGNI).
- `dictation_result_screen.dart` is untouched — it has no vocab-suggestions section (dictation doesn't source from arbitrary text the same way).
- No new tests for pre-existing behavior beyond what already exists — existing screen tests must continue passing unmodified (they assert on rendered text/behavior, not on which class produced it), proving the extraction is behavior-preserving.

## Design

### 1. `AiDisabledCard` (shared error card)

New file `lib/core/widgets/ai_disabled_card.dart`:

```dart
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

Each of the 5 home screens deletes its private `_ErrorCard` class and its usages become `AiDisabledCard(message: ...)`, imported from `../../../../core/widgets/ai_disabled_card.dart` (path adjusted per file's nesting depth). No behavior change — same widget tree shape, same styling, just a `super.key` added (harmless).

### 2. `ResultSuggestionsSection` (shared suggestions loader/renderer)

New file `lib/features/word_radar/presentation/widgets/result_suggestions_section.dart`:

```dart
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

Each of the 4 result screens:
- Deletes its `_suggestions` field, `_loadSuggestions()` method, and `_buildSuggestionsSection()` method.
- Keeps `initState()`'s `_recordPracticeSession()` call (unchanged, stays inline).
- Removes the `_loadSuggestions()` call from `initState()` (the new widget triggers its own load).
- Replaces the `_buildSuggestionsSection()` call-site in `build()` with `ResultSuggestionsSection(text: <existing per-screen text getter>, targetLanguage: <existing>, targetCefrLevel: <existing>)`.

Per-screen substitutions (the only thing that varies — verified from current code):

| Screen | `text` | `targetCefrLevel` |
|---|---|---|
| `reading_result_screen.dart` | `result.passage.fullText` | `result.passage.level` |
| `comprehension_result_screen.dart` | `result.passage.turns.map((t) => t.text).join(' ')` (existing `_transcriptText` getter) | `result.passage.level` |
| `part5_result_screen.dart` | `result.set.questions.map((q) => q.sentenceWithBlank).join(' ')` (existing `_questionsText` getter) | `null` |
| `part6_result_screen.dart` | `result.set.passages.map((p) => p.passageText).join(' ')` (existing `_passagesText` getter) | `null` |

`targetLanguage` is `result.passage.targetLanguage` (reading/comprehension) or `result.set.targetLanguage` (part5/part6) in all four — unchanged from current code, just passed as a constructor arg instead of used directly in a method body.

### Testing

No new widget tests are needed for `AiDisabledCard` or `ResultSuggestionsSection` in isolation — their behavior is already fully exercised by each consuming screen's existing test suite (AI-disabled state, suggestions loading/error/retry/data states are all already asserted per-screen). The proof this refactor is safe is that **all existing tests in the 9 touched screens' test files pass unmodified** — if any assertion needed to change, the extraction changed behavior and that's a bug.

## Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| `_recordPracticeSession` | Stays inline per screen | Tiny (5-7 lines), the count argument differs per screen, not worth an abstraction (YAGNI) |
| `dictation_result_screen.dart` | Untouched | No suggestions section exists there — different design, not part of this duplication |
| Where the shared widgets live | `core/widgets/` for the generic error card; `word_radar/presentation/widgets/` for the suggestions section | Matches existing precedent — `VocabSuggestionsSection` (which the new widget wraps) already lives in `word_radar`, and `core/widgets/` already holds cross-feature generic widgets (`FilterTile`, `selection_sheets.dart`) |
| Test strategy | No new isolated tests; rely on existing per-screen tests passing unmodified | This is a pure extraction — the safety net already exists in the 9 files' current test suites |
