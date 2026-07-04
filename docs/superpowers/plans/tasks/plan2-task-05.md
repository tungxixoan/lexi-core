# Plan 2 — Task 05: Use Cases

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 02, 03

## Global Constraints
(see `plan2-global-constraints.md`)
- Topic constraint: each VocabRecord max **2** topic tags — enforced here
- Sentences (`InputType.sentence`) are **never** saved — enforced here

## What This Task Delivers
Seven use case classes, each a thin wrapper over `VocabRepository` with validation logic:
- `SaveVocabUseCase` — validates ≤2 topics, rejects sentences
- `GetVocabListUseCase` — delegates with optional filters
- `UpdateVocabUseCase` — validates ≤2 topics, sets updatedAt
- `DeleteVocabUseCase` — delegates to repo
- `GetTopicsUseCase` — delegates to repo
- `AddTopicUseCase` — validates non-empty name, creates Topic with UUID
- `DeleteTopicUseCase` — rejects predefined topics, delegates

Unit tests: mock `VocabRepository` and test all validation paths.

## Files
- Create: `lib/features/vocabulary/domain/use_cases/save_vocab_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/update_vocab_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/get_topics_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/add_topic_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/delete_topic_use_case.dart`
- Create: `test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart`

## Interfaces From Prior Tasks

```dart
// From Task 02:
final class VocabRecord {
  final InputType inputType;
  final List<String> topicIds;
  // ...
}
final class Topic {
  const Topic({required String id, required String name, required String emoji,
                required bool isPredefined, required DateTime createdAt});
}

// From Task 03:
abstract interface class VocabRepository {
  Future<void> save(VocabRecord record);
  Future<List<VocabRecord>> getAll({String? topicId, InputType? inputType, Language? language});
  Future<VocabRecord?> getById(String id);
  Future<void> update(VocabRecord record);
  Future<void> delete(String id);
  Future<bool> existsByHeadword(String headword, Language language);
  Future<List<Topic>> getTopics();
  Future<void> addTopic(Topic topic);
  Future<void> deleteTopic(String id);
}

class VocabException implements Exception {
  const VocabException(String message);
}
```

## Produces (used by Tasks 06, 07, 09, 10)

```dart
class SaveVocabUseCase {
  const SaveVocabUseCase(VocabRepository repo);
  Future<void> execute(VocabRecord record);
  // throws VocabException if inputType == sentence or topicIds.length > 2
}

class GetVocabListUseCase {
  const GetVocabListUseCase(VocabRepository repo);
  Future<List<VocabRecord>> execute({String? topicId, InputType? inputType, Language? language});
}

class UpdateVocabUseCase {
  const UpdateVocabUseCase(VocabRepository repo);
  Future<void> execute(VocabRecord record);
  // throws VocabException if topicIds.length > 2; sets updatedAt = DateTime.now()
}

class DeleteVocabUseCase {
  const DeleteVocabUseCase(VocabRepository repo);
  Future<void> execute(String id);
}

class GetTopicsUseCase {
  const GetTopicsUseCase(VocabRepository repo);
  Future<List<Topic>> execute();
}

class AddTopicUseCase {
  const AddTopicUseCase(VocabRepository repo);
  Future<Topic> execute({required String name, required String emoji});
  // throws VocabException if name.trim().isEmpty; uses uuid v4 for id
}

class DeleteTopicUseCase {
  const DeleteTopicUseCase(VocabRepository repo);
  Future<void> execute(String topicId, {required bool isPredefined});
  // throws VocabException if isPredefined == true
}
```

## Steps

- [ ] **Step 1: Write failing tests**

Create `test/features/vocabulary/domain/use_cases/` directory (if needed), then write the test file:

```dart
// test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/add_topic_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/delete_topic_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/save_vocab_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/update_vocab_use_case.dart';

import 'vocab_use_cases_test.mocks.dart';

@GenerateMocks([VocabRepository])
void main() {
  late MockVocabRepository mockRepo;
  final now = DateTime(2026, 6, 30);

  VocabRecord makeRecord({
    List<String> topicIds = const ['daily-life'],
    InputType type = InputType.word,
  }) =>
      VocabRecord(
        id: 'abc-123',
        headword: 'allow',
        inputType: type,
        ipa: '/əˈlaʊ/',
        meaning: 'cho phép',
        examples: const ['She allowed him to go.'],
        personalNotes: '',
        topicIds: topicIds,
        targetLanguage: Language.english,
        cefrLevel: CEFRLevel.b1,
        activeContext: AppContext.general,
        createdAt: now,
        updatedAt: now,
      );

  setUp(() {
    mockRepo = MockVocabRepository();
    when(mockRepo.save(any)).thenAnswer((_) async {});
    when(mockRepo.update(any)).thenAnswer((_) async {});
    when(mockRepo.delete(any)).thenAnswer((_) async {});
    when(mockRepo.deleteTopic(any)).thenAnswer((_) async {});
    when(mockRepo.addTopic(any)).thenAnswer((_) async {});
    when(mockRepo.getAll()).thenAnswer((_) async => []);
  });

  group('SaveVocabUseCase', () {
    test('saves valid word record', () async {
      await SaveVocabUseCase(mockRepo).execute(makeRecord());
      verify(mockRepo.save(any)).called(1);
    });

    test('saves valid phrase record', () async {
      await SaveVocabUseCase(mockRepo).execute(makeRecord(type: InputType.phrase));
      verify(mockRepo.save(any)).called(1);
    });

    test('throws VocabException for sentence inputType', () {
      expect(
        () => SaveVocabUseCase(mockRepo).execute(makeRecord(type: InputType.sentence)),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.save(any));
    });

    test('throws VocabException when topicIds.length > 2', () {
      expect(
        () => SaveVocabUseCase(mockRepo).execute(makeRecord(topicIds: ['a', 'b', 'c'])),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.save(any));
    });

    test('allows exactly 2 topic ids', () async {
      await SaveVocabUseCase(mockRepo).execute(makeRecord(topicIds: ['a', 'b']));
      verify(mockRepo.save(any)).called(1);
    });
  });

  group('UpdateVocabUseCase', () {
    test('throws VocabException when topicIds.length > 2', () {
      expect(
        () => UpdateVocabUseCase(mockRepo).execute(makeRecord(topicIds: ['a', 'b', 'c'])),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.update(any));
    });

    test('updates updatedAt to now (not older than record)', () async {
      final before = DateTime.now();
      await UpdateVocabUseCase(mockRepo).execute(makeRecord());
      final after = DateTime.now();
      final captured = verify(mockRepo.update(captureAny)).captured.first as VocabRecord;
      expect(
        captured.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))) &&
            captured.updatedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });

  group('DeleteVocabUseCase', () {
    test('calls repo.delete with given id', () async {
      await DeleteVocabUseCase(mockRepo).execute('my-id');
      verify(mockRepo.delete('my-id')).called(1);
    });
  });

  group('GetVocabListUseCase', () {
    test('delegates to repo with no filters', () async {
      when(mockRepo.getAll()).thenAnswer((_) async => [makeRecord()]);
      final result = await GetVocabListUseCase(mockRepo).execute();
      expect(result.length, 1);
    });

    test('passes topicId filter to repo', () async {
      when(mockRepo.getAll(topicId: 'business')).thenAnswer((_) async => []);
      await GetVocabListUseCase(mockRepo).execute(topicId: 'business');
      verify(mockRepo.getAll(topicId: 'business')).called(1);
    });
  });

  group('DeleteTopicUseCase', () {
    test('throws VocabException for predefined topic', () {
      expect(
        () => DeleteTopicUseCase(mockRepo).execute('daily-life', isPredefined: true),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.deleteTopic(any));
    });

    test('allows deleting custom topic', () async {
      await DeleteTopicUseCase(mockRepo).execute('my-custom-id', isPredefined: false);
      verify(mockRepo.deleteTopic('my-custom-id')).called(1);
    });
  });

  group('AddTopicUseCase', () {
    test('throws VocabException for empty name', () {
      expect(
        () => AddTopicUseCase(mockRepo).execute(name: '   ', emoji: '⭐'),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.addTopic(any));
    });

    test('creates topic with non-empty UUID and trimmed name', () async {
      final topic = await AddTopicUseCase(mockRepo).execute(name: '  My Topic  ', emoji: '⭐');
      expect(topic.id, isNotEmpty);
      expect(topic.id.length, greaterThan(4)); // UUID v4 is 36 chars
      expect(topic.name, 'My Topic');
      expect(topic.emoji, '⭐');
      expect(topic.isPredefined, isFalse);
      verify(mockRepo.addTopic(any)).called(1);
    });

    test('uses default emoji when empty', () async {
      final topic = await AddTopicUseCase(mockRepo).execute(name: 'Test', emoji: '');
      expect(topic.emoji, '📌');
    });
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `test/features/vocabulary/domain/use_cases/vocab_use_cases_test.mocks.dart`

- [ ] **Step 3: Run tests — expect FAIL**

```bash
flutter test test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart
```

Expected: compile error — use case classes not defined yet.

- [ ] **Step 4: Implement all use cases**

Create `lib/features/vocabulary/domain/use_cases/` directory, then create each file:

**save_vocab_use_case.dart:**
```dart
// lib/features/vocabulary/domain/use_cases/save_vocab_use_case.dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class SaveVocabUseCase {
  const SaveVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(VocabRecord record) {
    if (record.inputType == InputType.sentence) {
      throw const VocabException('Sentences cannot be saved to Vocabulary Bank.');
    }
    if (record.topicIds.length > 2) {
      throw const VocabException('A word can have at most 2 topic tags.');
    }
    return _repo.save(record);
  }
}
```

**get_vocab_list_use_case.dart:**
```dart
// lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class GetVocabListUseCase {
  const GetVocabListUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<VocabRecord>> execute({
    String? topicId,
    InputType? inputType,
    Language? language,
  }) =>
      _repo.getAll(topicId: topicId, inputType: inputType, language: language);
}
```

**update_vocab_use_case.dart:**
```dart
// lib/features/vocabulary/domain/use_cases/update_vocab_use_case.dart
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class UpdateVocabUseCase {
  const UpdateVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(VocabRecord record) {
    if (record.topicIds.length > 2) {
      throw const VocabException('A word can have at most 2 topic tags.');
    }
    return _repo.update(record.copyWith(updatedAt: DateTime.now()));
  }
}
```

**delete_vocab_use_case.dart:**
```dart
// lib/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart
import '../repositories/vocab_repository.dart';

class DeleteVocabUseCase {
  const DeleteVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(String id) => _repo.delete(id);
}
```

**get_topics_use_case.dart:**
```dart
// lib/features/vocabulary/domain/use_cases/get_topics_use_case.dart
import '../entities/topic.dart';
import '../repositories/vocab_repository.dart';

class GetTopicsUseCase {
  const GetTopicsUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<Topic>> execute() => _repo.getTopics();
}
```

**add_topic_use_case.dart:**
```dart
// lib/features/vocabulary/domain/use_cases/add_topic_use_case.dart
import 'package:uuid/uuid.dart';
import '../entities/topic.dart';
import '../repositories/vocab_repository.dart';

class AddTopicUseCase {
  const AddTopicUseCase(this._repo);
  final VocabRepository _repo;

  Future<Topic> execute({required String name, required String emoji}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const VocabException('Topic name cannot be empty.');
    }
    final topic = Topic(
      id: const Uuid().v4(),
      name: trimmed,
      emoji: emoji.trim().isEmpty ? '📌' : emoji.trim(),
      isPredefined: false,
      createdAt: DateTime.now(),
    );
    await _repo.addTopic(topic);
    return topic;
  }
}
```

**delete_topic_use_case.dart:**
```dart
// lib/features/vocabulary/domain/use_cases/delete_topic_use_case.dart
import '../repositories/vocab_repository.dart';

class DeleteTopicUseCase {
  const DeleteTopicUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(String topicId, {required bool isPredefined}) {
    if (isPredefined) {
      throw const VocabException('Predefined topics cannot be deleted.');
    }
    return _repo.deleteTopic(topicId);
  }
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Run full suite**

```bash
flutter test
```

Expected: all existing tests still pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/vocabulary/domain/use_cases/ \
        test/features/vocabulary/domain/use_cases/
git commit -m "feat(plan2): add 7 vocab use cases with validation; 12 tests passing"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed
Concerns: (if any)
