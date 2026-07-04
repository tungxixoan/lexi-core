# Plan 2 — Task 11: VocabBank Lookup Cache

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 06 (vocabRepositoryProvider available)

## Global Constraints
(see `plan2-global-constraints.md`)

## What This Task Delivers
Modifies `LookupNotifier.lookup()` to check the VocabBank before calling the API. If the typed word/phrase already exists as a saved VocabRecord (same headword + targetLanguage), return the saved data immediately — no API call. Sentences are always looked up via API (no VocabBank cache for sentences).

This means repeat lookups of saved words are instant and offline-ready.

## Files
- Modify: `lib/features/dictionary/presentation/providers/lookup_provider.dart`

## Interfaces From Prior Tasks

```dart
// From Plan 1 — existing lookup_provider.dart:
@riverpod
class LookupNotifier extends _$LookupNotifier {
  @override
  AsyncValue<LookupResult?> build() => const AsyncValue.data(null);

  Future<void> lookup(String query, InputType inputType) async { ... }
}

// From Task 06 — new provider:
// vocabRepositoryProvider → VocabRepository

// From Task 03 — VocabRepository:
// getByHeadword(String headword, Language language) → Future<VocabRecord?>

// From Task 02 — VocabRecord:
final class VocabRecord {
  final String headword;
  final InputType inputType;
  final String ipa;
  final String meaning;
  final List<String> examples;
  final List<String> topicIds;
  final Language targetLanguage;
}

// From Plan 1 — LookupResult:
sealed class LookupResult {}
final class WordPhraseResult extends LookupResult {
  const WordPhraseResult({
    required String headword, required InputType inputType,
    required String ipa, required String meaning,
    required List<String> examples, required List<String> suggestedTopics,
  });
}

// From Plan 1 — user settings:
// userSettingsNotifierProvider → UserSettingsState { targetLanguage: Language }
```

## Steps

- [ ] **Step 1: Read existing lookup_provider.dart**

Read `lib/features/dictionary/presentation/providers/lookup_provider.dart` to understand the current structure.

- [ ] **Step 2: Add VocabBank import and modify lookup()**

Add the import for vocab repository (the provider is in `app_providers.dart` which is already imported, or import `vocab_repository.dart` if needed).

Add to the top of `lookup_provider.dart` if not already present:
```dart
import '../../../../features/vocabulary/domain/repositories/vocab_repository.dart';
```

Then modify the `lookup()` method. Find the existing `lookup()` body and wrap the API call with a VocabBank check. The new `lookup()` should be:

```dart
Future<void> lookup(String query, InputType inputType) async {
  state = const AsyncValue.loading();
  try {
    final settings = ref.read(userSettingsNotifierProvider);

    // VocabBank cache: for word/phrase only, check saved records first
    if (inputType != InputType.sentence) {
      final cached = await ref
          .read(vocabRepositoryProvider)
          .getByHeadword(query.trim(), settings.targetLanguage);
      if (cached != null) {
        state = AsyncValue.data(
          WordPhraseResult(
            headword: cached.headword,
            inputType: cached.inputType,
            ipa: cached.ipa,
            meaning: cached.meaning,
            examples: cached.examples,
            suggestedTopics: const [],
          ),
        );
        return;
      }
    }

    // Fallback: call the API as before
    final result = await ref.read(lookupUseCaseProvider).execute(
          query: query,
          inputType: inputType,
          targetLanguage: settings.targetLanguage,
          activeContext: settings.activeContext,
          aiEnabled: settings.aiEnabled,
          geminiApiKey: settings.geminiApiKey,
        );
    state = AsyncValue.data(result);
  } catch (e, st) {
    state = AsyncValue.error(e, st);
  }
}
```

**Important:** The existing `lookup()` call `ref.read(lookupUseCaseProvider).execute(...)` uses named parameters. Match the exact parameter names from the existing code — read the file first to confirm them.

Also add this import near the top of the file if not already there:
```dart
import '../../../../core/di/app_providers.dart';
```

(`vocabRepositoryProvider` is defined in `app_providers.dart`)

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/features/dictionary/presentation/providers/lookup_provider.dart
```

Expected: no errors.

- [ ] **Step 4: Run full test suite**

```bash
flutter test
```

Expected: all existing tests still pass. The change is additive — tests mock `lookupUseCaseProvider` and `vocabRepositoryProvider` so the new path doesn't break them.

Note: If tests fail because `vocabRepositoryProvider` is not mocked in existing test setup, add a mock or override it in the test's `ProviderScope`. The existing `lookup_provider_test.dart` likely uses `ProviderContainer` — add:
```dart
vocabRepositoryProvider.overrideWith((ref) => mockVocabRepo),
```
where `mockVocabRepo.getByHeadword(any, any)` returns `Future.value(null)` so the cache always misses in tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dictionary/presentation/providers/lookup_provider.dart \
        test/features/dictionary/presentation/providers/lookup_provider_test.dart
git commit -m "feat(plan2): check VocabBank before API call in LookupNotifier"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (SHA)
Tests: X/X passed
Analyze: no errors
Concerns: (if any)
