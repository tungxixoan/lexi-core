# Plan 2 — Task 04: VocabRepositoryImpl

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 01, 02, 03

## Global Constraints
(see `plan2-global-constraints.md`)
- Hive storage: `Box<String>` with `jsonEncode/jsonDecode` — NO Hive code generation
- Box names: `'vocab_records'` and `'topics'` (opened in main.dart)
- Deleting a custom topic: auto-moves affected words to topic id `'other'`

## What This Task Delivers
The Hive-backed implementation of `VocabRepository`. Stores records as JSON strings in two Hive boxes. Seeds the 20 predefined topics on first run. No tests — the use cases (Task 05) test via mock, and integration is verified via `flutter analyze`.

## Files
- Create: `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`

## Interfaces From Prior Tasks

```dart
// From Task 02:
final class VocabRecord {
  Map<String, dynamic> toJson();
  factory VocabRecord.fromJson(Map<String, dynamic> json);
  VocabRecord copyWith({List<String>? topicIds, DateTime? updatedAt, ...});
  final List<String> topicIds;
}

final class Topic {
  Map<String, dynamic> toJson();
  factory Topic.fromJson(Map<String, dynamic> json);
  static final List<Topic> predefined; // 20 items
}

// From Task 03:
abstract interface class VocabRepository { ... }
```

## Produces (used by Tasks 05, 06)

```dart
class VocabRepositoryImpl implements VocabRepository {
  const VocabRepositoryImpl();
  // All 9 VocabRepository methods implemented
}
```

## Steps

- [ ] **Step 1: Create vocab_repository_impl.dart**

Create the directory `lib/features/vocabulary/data/repositories/` then create the file:

```dart
// lib/features/vocabulary/data/repositories/vocab_repository_impl.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/vocab_record.dart';
import '../../domain/repositories/vocab_repository.dart';
import '../../../../features/dictionary/domain/entities/input_type.dart';
import '../../../../features/dictionary/domain/entities/language.dart';

class VocabRepositoryImpl implements VocabRepository {
  const VocabRepositoryImpl();

  static const _vocabBoxName = 'vocab_records';
  static const _topicsBoxName = 'topics';

  Box<String> get _vocabBox => Hive.box<String>(_vocabBoxName);
  Box<String> get _topicsBox => Hive.box<String>(_topicsBoxName);

  @override
  Future<void> save(VocabRecord record) async {
    await _vocabBox.put(record.id, jsonEncode(record.toJson()));
  }

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
  }) async {
    var records = _vocabBox.values
        .map((s) => VocabRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    if (topicId != null) {
      records = records.where((r) => r.topicIds.contains(topicId)).toList();
    }
    if (inputType != null) {
      records = records.where((r) => r.inputType == inputType).toList();
    }
    if (language != null) {
      records = records.where((r) => r.targetLanguage == language).toList();
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  @override
  Future<VocabRecord?> getById(String id) async {
    final raw = _vocabBox.get(id);
    if (raw == null) return null;
    return VocabRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> update(VocabRecord record) async {
    await _vocabBox.put(record.id, jsonEncode(record.toJson()));
  }

  @override
  Future<void> delete(String id) async {
    await _vocabBox.delete(id);
  }

  @override
  Future<bool> existsByHeadword(String headword, Language language) async {
    return _vocabBox.values.any((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return (map['headword'] as String).toLowerCase() == headword.toLowerCase() &&
          map['targetLanguage'] == language.name;
    });
  }

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async {
    final lc = headword.toLowerCase();
    for (final s in _vocabBox.values) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      if ((map['headword'] as String).toLowerCase() == lc &&
          map['targetLanguage'] == language.name) {
        return VocabRecord.fromJson(map);
      }
    }
    return null;
  }

  @override
  Future<List<Topic>> getTopics() async {
    if (_topicsBox.isEmpty) {
      await _seedTopics();
    }
    final topics = _topicsBox.values
        .map((s) => Topic.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    topics.sort((a, b) {
      if (a.isPredefined && !b.isPredefined) return -1;
      if (!a.isPredefined && b.isPredefined) return 1;
      return a.name.compareTo(b.name);
    });
    return topics;
  }

  @override
  Future<void> addTopic(Topic topic) async {
    await _topicsBox.put(topic.id, jsonEncode(topic.toJson()));
  }

  @override
  Future<void> deleteTopic(String id) async {
    // Reassign all words with this topic to 'other'
    final all = await getAll();
    for (final record in all) {
      if (record.topicIds.contains(id)) {
        final newTopicIds = record.topicIds.where((t) => t != id).toList();
        if (newTopicIds.isEmpty) newTopicIds.add('other');
        await update(record.copyWith(
          topicIds: newTopicIds,
          updatedAt: DateTime.now(),
        ));
      }
    }
    await _topicsBox.delete(id);
  }

  Future<void> _seedTopics() async {
    for (final topic in Topic.predefined) {
      await _topicsBox.put(topic.id, jsonEncode(topic.toJson()));
    }
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/vocabulary/data/
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/vocabulary/data/
git commit -m "feat(plan2): add VocabRepositoryImpl with Hive JSON storage and topic seeding"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Analyze: no errors
Concerns: (if any)
