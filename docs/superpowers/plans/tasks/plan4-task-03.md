# Plan 4 — Task 03: CEFR filter in VocabRepository + GetVocabListUseCase

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01 (packages available). Tasks 02 and 03 can run in parallel.

## What this task builds

Adds `CEFRLevel? maxCefrLevel` parameter to `VocabRepository.getAll()` and `GetVocabListUseCase.execute()`. The filter logic is: `record.cefrLevel.index <= maxCefrLevel.index`. Includes 2 unit tests via mock repository.

## Files

- Modify: `lib/features/vocabulary/domain/repositories/vocab_repository.dart`
- Modify: `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`
- Modify: `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`
- Create: `test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart`

## Interfaces consumed

```dart
// lib/features/vocabulary/domain/entities/cefr_level.dart
enum CEFRLevel { a1, a2, b1, b2, c1, c2 }
// CEFRLevel.b1.index == 2, CEFRLevel.b2.index == 3
// filter: r.cefrLevel.index <= maxCefrLevel.index

// VocabRecord.cefrLevel — already exists on every record
```

## Interfaces produced

```dart
// VocabRepository.getAll() — updated signature:
Future<List<VocabRecord>> getAll({
  String? topicId,
  InputType? inputType,
  Language? language,
  CEFRLevel? maxCefrLevel,  // NEW — null = no filter
});

// GetVocabListUseCase.execute() — updated signature:
Future<List<VocabRecord>> execute({
  String? topicId,
  InputType? inputType,
  Language? language,
  CEFRLevel? maxCefrLevel,  // NEW — passed through to repo
});
```

---

- [ ] **Step 1: Write the failing tests**

Create `test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockVocabRepository extends Mock implements VocabRepository {}

VocabRecord _makeRecord(String id, CEFRLevel level) => VocabRecord(
      id: id,
      headword: id,
      inputType: InputType.word,
      ipa: '',
      meaning: '',
      examples: [],
      personalNotes: '',
      topicIds: [],
      targetLanguage: Language.english,
      cefrLevel: level,
      activeContext: AppContext.general,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

void main() {
  late MockVocabRepository repo;
  late GetVocabListUseCase useCase;

  setUp(() {
    repo = MockVocabRepository();
    useCase = GetVocabListUseCase(repo);
  });

  test('execute() with no maxCefrLevel passes null to repo', () async {
    when(() => repo.getAll(
          topicId: any(named: 'topicId'),
          inputType: any(named: 'inputType'),
          language: any(named: 'language'),
          maxCefrLevel: any(named: 'maxCefrLevel'),
        )).thenAnswer((_) async => []);

    await useCase.execute();

    verify(() => repo.getAll(
          topicId: null,
          inputType: null,
          language: null,
          maxCefrLevel: null,
        )).called(1);
  });

  test('execute() passes maxCefrLevel to repo and returns its result', () async {
    final records = [_makeRecord('word1', CEFRLevel.b1)];
    when(() => repo.getAll(
          topicId: any(named: 'topicId'),
          inputType: any(named: 'inputType'),
          language: any(named: 'language'),
          maxCefrLevel: any(named: 'maxCefrLevel'),
        )).thenAnswer((_) async => records);

    final result = await useCase.execute(maxCefrLevel: CEFRLevel.b2);

    verify(() => repo.getAll(
          topicId: null,
          inputType: null,
          language: null,
          maxCefrLevel: CEFRLevel.b2,
        )).called(1);
    expect(result, records);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```
flutter test test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
```

Expected: FAIL — `GetVocabListUseCase.execute()` doesn't accept `maxCefrLevel` yet.

- [ ] **Step 3: Update VocabRepository interface**

Open `lib/features/vocabulary/domain/repositories/vocab_repository.dart`. Add the import for `CEFRLevel` at the top, then add `maxCefrLevel` to `getAll()`:

```dart
import '../entities/cefr_level.dart';
// (keep existing imports)

abstract interface class VocabRepository {
  Future<void> save(VocabRecord record);

  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,  // ← NEW
  });

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

Note: only add `maxCefrLevel` to the `getAll()` signature. All other methods stay unchanged.

- [ ] **Step 4: Update VocabRepositoryImpl**

Open `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`. Add the import for `CEFRLevel` and update `getAll()` to accept and apply the new parameter:

```dart
import '../../domain/entities/cefr_level.dart';
// (keep existing imports)
```

Update `getAll()` — add `CEFRLevel? maxCefrLevel` parameter and the filter block after the existing filters:

```dart
@override
Future<List<VocabRecord>> getAll({
  String? topicId,
  InputType? inputType,
  Language? language,
  CEFRLevel? maxCefrLevel,  // ← NEW
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
  if (maxCefrLevel != null) {
    records = records
        .where((r) => r.cefrLevel.index <= maxCefrLevel.index)
        .toList();
  }
  records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return records;
}
```

- [ ] **Step 5: Update GetVocabListUseCase**

Replace `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart` with:

```dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/cefr_level.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class GetVocabListUseCase {
  const GetVocabListUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<VocabRecord>> execute({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
  }) =>
      _repo.getAll(
        topicId: topicId,
        inputType: inputType,
        language: language,
        maxCefrLevel: maxCefrLevel,
      );
}
```

- [ ] **Step 6: Run tests — expect pass**

```
flutter test test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
```

Expected: 2/2 PASS.

- [ ] **Step 7: Run full suite**

```
flutter test
```

Expected: all passing.

- [ ] **Step 8: Analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 9: Commit**

```
git add lib/features/vocabulary/domain/repositories/vocab_repository.dart lib/features/vocabulary/data/repositories/vocab_repository_impl.dart lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
git commit -m "feat(plan4): add CEFRLevel filter to VocabRepository and GetVocabListUseCase"
```

## Self-review checklist

- [ ] Filter uses `<=` (not `<`) — `maxCefrLevel: CEFRLevel.b2` includes b2 words
- [ ] Filter is `cefrLevel.index <= maxCefrLevel.index` (compare indexes, not enum identity)
- [ ] `null` maxCefrLevel means no filter (all words returned)
- [ ] All other `getAll()` filters (topicId, inputType, language) are preserved unchanged
- [ ] 2/2 use case tests pass
- [ ] Full suite still passes
- [ ] `flutter analyze lib/` clean
