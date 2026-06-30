# Task 15: Lookup Screen (Assembly)

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 10, 11, 12, 13, 14 (all widgets and providers exist)

## Interfaces From Prior Tasks
- `ContextSelectorWidget` — no params, self-contained
- `SearchBarWidget` — no params, self-contained
- `WordResultWidget({ required WordPhraseResult result })`
- `SentenceResultWidget({ required SentenceResult result })`
- `lookupNotifierProvider` → `AsyncValue<LookupResult?>` — three states: data(null), loading, data(result), error
- `LookupResult` sealed class → `WordPhraseResult` | `SentenceResult`

## What This Task Delivers
Replaces the placeholder `LookupScreen` with the real assembled screen. Runs full test suite and manual `flutter run` verification.

## Files
- Modify: `lib/features/dictionary/presentation/screens/lookup_screen.dart` *(replace placeholder)*

## Steps

- [ ] **Step 1: Replace placeholder with full LookupScreen**

```dart
// lib/features/dictionary/presentation/screens/lookup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/lookup_provider.dart';
import '../widgets/context_selector_widget.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sentence_result_widget.dart';
import '../widgets/word_result_widget.dart';

class LookupScreen extends ConsumerWidget {
  const LookupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookupState = ref.watch(lookupNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LexiCore'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const ContextSelectorWidget(),
          const SearchBarWidget(),
          const Divider(height: 1),
          Expanded(
            child: lookupState.when(
              data: (result) {
                if (result == null) {
                  return const Center(
                    child: Text(
                      'Enter a word, phrase, or sentence to get started.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: switch (result) {
                    WordPhraseResult r => WordResultWidget(result: r),
                    SentenceResult r => SentenceResultWidget(result: r),
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run full test suite**

```bash
flutter test
```

Expected: all green.

- [ ] **Step 3: Run the app — manual verification checklist**

```bash
flutter run
```

Verify each item:
- [ ] Context selector scrolls horizontally; tapping a chip highlights it
- [ ] Typing "follow" + search → word result: headword, IPA, meaning, examples, TTS buttons
- [ ] Typing "follow up" → phrase result (same card layout as word)
- [ ] Typing "Can you follow up with me today?" → sentence result: original + translation + TTS button, no Save button
- [ ] Discover button (✨) visible when AI is on → tap shows loading then a new word result
- [ ] Loading spinner shows during API call
- [ ] Error message (red text) shown when Gemini API key is missing

- [ ] **Step 4: Commit**

```bash
git add lib/features/dictionary/presentation/screens/lookup_screen.dart
git commit -m "feat: complete LookupScreen — Plan 1 dictionary lookup feature done"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed — `flutter test`
Manual verification: all checklist items passed (or list any that failed)
Concerns: (if any)
