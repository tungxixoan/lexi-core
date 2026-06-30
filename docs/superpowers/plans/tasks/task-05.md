# Task 5: Dictionary Repository Interface + Exception

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 2 (AppContext, Language, LookupResult entities)

## What This Task Delivers
The `DictionaryException` typed exception and `DictionaryRepository` abstract interface. No tests needed (pure interface definition).

## Files
- Create: `lib/features/dictionary/domain/repositories/dictionary_repository.dart`

## Produces (used by Tasks 6, 7, 8, 9, 10)
```dart
class DictionaryException implements Exception {
  const DictionaryException(this.message);
  final String message;
}

abstract interface class DictionaryRepository {
  Future<LookupResult> lookup({
    required String query,
    required Language targetLanguage,
    required AppContext context,
    required bool aiEnabled,
  });
}
```

## Steps

- [ ] **Step 1: Create dictionary_repository.dart**

```dart
// lib/features/dictionary/domain/repositories/dictionary_repository.dart
import '../entities/app_context.dart';
import '../entities/language.dart';
import '../entities/lookup_result.dart';

class DictionaryException implements Exception {
  const DictionaryException(this.message);
  final String message;

  @override
  String toString() => 'DictionaryException: $message';
}

abstract interface class DictionaryRepository {
  Future<LookupResult> lookup({
    required String query,
    required Language targetLanguage,
    required AppContext context,
    required bool aiEnabled,
  });
}
```

- [ ] **Step 2: Verify compilation**

```bash
flutter analyze lib/features/dictionary/domain/repositories/
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dictionary/domain/repositories/
git commit -m "feat: add DictionaryRepository interface and DictionaryException"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: N/A
Concerns: (if any)
