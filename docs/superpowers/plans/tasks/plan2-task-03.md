# Plan 2 — Task 03: VocabRepository Interface

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 02

## Global Constraints
(see `plan2-global-constraints.md`)

## What This Task Delivers
The abstract `VocabRepository` interface and `VocabException` class. This defines the contract that both `VocabRepositoryImpl` (Task 04) and mock test doubles (Task 05) must fulfill.

## Files
- Create: `lib/features/vocabulary/domain/repositories/vocab_repository.dart`

## Interfaces From Prior Tasks

```dart
// From Task 02:
final class VocabRecord { ... }
final class Topic { ... }
enum CEFRLevel { a1, a2, b1, b2, c1, c2 }

// From Plan 1:
enum InputType { word, phrase, sentence }
enum Language { english, chinese, korean, japanese }
```

## Produces (used by Tasks 04, 05, 06)

```dart
class VocabException implements Exception {
  const VocabException(String message);
  final String message;
}

abstract interface class VocabRepository {
  Future<void> save(VocabRecord record);
  Future<List<VocabRecord>> getAll({String? topicId, InputType? inputType, Language? language});
  Future<VocabRecord?> getById(String id);
  Future<void> update(VocabRecord record);
  Future<void> delete(String id);
  Future<bool> existsByHeadword(String headword, Language language);
  Future<VocabRecord?> getByHeadword(String headword, Language language);
  Future<List<Topic>> getTopics();
  Future<void> addTopic(Topic topic);
  Future<void> deleteTopic(String id);
}
```

## Steps

- [ ] **Step 1: Create vocab_repository.dart**

```dart
// lib/features/vocabulary/domain/repositories/vocab_repository.dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/topic.dart';
import '../entities/vocab_record.dart';

class VocabException implements Exception {
  const VocabException(this.message);
  final String message;

  @override
  String toString() => 'VocabException: $message';
}

abstract interface class VocabRepository {
  /// Saves a new vocab record. Throws [VocabException] if already exists.
  Future<void> save(VocabRecord record);

  /// Returns all records, optionally filtered.
  /// Results are sorted newest-first by [createdAt].
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
  });

  Future<VocabRecord?> getById(String id);

  Future<void> update(VocabRecord record);

  Future<void> delete(String id);

  /// Returns true if a VocabRecord with matching headword + language exists.
  Future<bool> existsByHeadword(String headword, Language language);

  /// Returns the first VocabRecord whose headword matches (case-insensitive) for a given language.
  /// Returns null if not found. Used by LookupNotifier to serve saved records without an API call.
  Future<VocabRecord?> getByHeadword(String headword, Language language);

  /// Returns all topics: predefined first (alphabetical), then custom (alphabetical).
  /// Seeds predefined topics on first call if box is empty.
  Future<List<Topic>> getTopics();

  Future<void> addTopic(Topic topic);

  /// Deletes a custom topic and reassigns its words to topic 'other'.
  /// Caller must verify the topic is not predefined before calling.
  Future<void> deleteTopic(String id);
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/vocabulary/domain/repositories/
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/vocabulary/domain/repositories/
git commit -m "feat(plan2): add VocabRepository interface and VocabException"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Analyze: no errors
Concerns: (if any)
