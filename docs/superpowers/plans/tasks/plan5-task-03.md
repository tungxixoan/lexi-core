# Plan 5 — Task 03: dueOnly Filter in VocabRepository + UseCase

**Context:** Task 03 of Plan 5. Task 01 (packages) must be complete. See `plan5-global-constraints.md` for project-wide rules.

**Files:**
- Modify: `lib/features/vocabulary/domain/repositories/vocab_repository.dart`
- Modify: `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`
- Modify: `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`
- Modify: `test/features/dictionary/presentation/providers/lookup_provider_test.mocks.dart`
- Modify: `test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart`

**Interfaces:**
- Produces:
  - `VocabRepository.getAll({String? topicId, InputType? inputType, Language? language, CEFRLevel? maxCefrLevel, bool dueOnly = false}) → Future<List<VocabRecord>>`
  - `GetVocabListUseCase.execute({..., bool dueOnly = false}) → Future<List<VocabRecord>>`
- Due threshold (from global constraints): `nextReviewAt == null || nextReviewAt!.isBefore(DateTime.now())`
- Consumed by: Task 05 (ProgressScreen), Task 07 (PracticeHomeScreen "Ôn hôm nay")

---

- [ ] **Step 1: Write failing test**

Add to `test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart` inside the main test group:

```dart
    test('execute with dueOnly=true passes dueOnly to repository', () async {
      when(() => mockRepo.getAll(dueOnly: true)).thenAnswer((_) async => []);
      await useCase.execute(dueOnly: true);
      verify(() => mockRepo.getAll(dueOnly: true)).called(1);
    });
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
```

Expected: FAIL (no `dueOnly` param on `getAll`).

- [ ] **Step 3: Update VocabRepository interface**

In `lib/features/vocabulary/domain/repositories/vocab_repository.dart`, update `getAll` signature to add `bool dueOnly = false`:

```dart
Future<List<VocabRecord>> getAll({
  String? topicId,
  InputType? inputType,
  Language? language,
  CEFRLevel? maxCefrLevel,
  bool dueOnly = false,
});
```

- [ ] **Step 4: Update VocabRepositoryImpl**

In `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`, add `bool dueOnly = false` to the `getAll` signature and add a filter block after the `maxCefrLevel` block:

```dart
@override
Future<List<VocabRecord>> getAll({
  String? topicId,
  InputType? inputType,
  Language? language,
  CEFRLevel? maxCefrLevel,
  bool dueOnly = false,
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
  if (dueOnly) {
    final now = DateTime.now();
    records = records
        .where((r) => r.nextReviewAt == null || r.nextReviewAt!.isBefore(now))
        .toList();
  }
  records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return records;
}
```

- [ ] **Step 5: Update GetVocabListUseCase**

Replace the full content of `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`:

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
    bool dueOnly = false,
  }) =>
      _repo.getAll(
        topicId: topicId,
        inputType: inputType,
        language: language,
        maxCefrLevel: maxCefrLevel,
        dueOnly: dueOnly,
      );
}
```

- [ ] **Step 6: Patch MockVocabRepository**

In `test/features/dictionary/presentation/providers/lookup_provider_test.mocks.dart`, find the `getAll` override and add `bool dueOnly = false` to both the parameter list and the `Invocation.method` map:

```dart
  @override
  _i4.Future<List<_i5.VocabRecord>> getAll({
    String? topicId,
    _i6.InputType? inputType,
    _i7.Language? language,
    _i8.CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) =>
      (super.noSuchMethod(
        _i2.Invocation.method(
          #getAll,
          [],
          {
            #topicId: topicId,
            #inputType: inputType,
            #language: language,
            #maxCefrLevel: maxCefrLevel,
            #dueOnly: dueOnly,
          },
        ),
        returnValue: _i4.Future<List<_i5.VocabRecord>>.value(<_i5.VocabRecord>[]),
      ) as _i4.Future<List<_i5.VocabRecord>>);
```

- [ ] **Step 7: Run tests — now pass**

```
flutter test test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 8: Run full suite**

```
flutter test
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```
git add lib/features/vocabulary/domain/repositories/vocab_repository.dart \
        lib/features/vocabulary/data/repositories/vocab_repository_impl.dart \
        lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart \
        test/features/dictionary/presentation/providers/lookup_provider_test.mocks.dart \
        test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
git commit -m "feat(plan5): add dueOnly filter to VocabRepository and GetVocabListUseCase"
```

**Report status:** DONE
