# Plan 2 — Task 06: Riverpod Providers + DI

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 03, 04, 05

## Global Constraints
(see `plan2-global-constraints.md`)
- Riverpod 2.x with `@riverpod` annotation only — no StateNotifier, no ChangeNotifier
- After editing any `@riverpod` file: run `dart run build_runner build --delete-conflicting-outputs`

## What This Task Delivers
Two Riverpod async notifiers (`VocabBankNotifier`, `TopicsNotifier`) and all DI provider wiring in `app_providers.dart`. These are consumed by the UI tasks (07, 09, 10).

## Files
- Create: `lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart`
- Create: `lib/features/vocabulary/presentation/providers/topics_provider.dart`
- Modify: `lib/core/di/app_providers.dart`

## Interfaces From Prior Tasks

```dart
// From Task 03:
abstract interface class VocabRepository { ... }

// From Task 04:
class VocabRepositoryImpl implements VocabRepository {
  const VocabRepositoryImpl();
}

// From Task 05:
class SaveVocabUseCase { const SaveVocabUseCase(VocabRepository repo); Future<void> execute(VocabRecord); }
class GetVocabListUseCase { const GetVocabListUseCase(VocabRepository repo); Future<List<VocabRecord>> execute({String? topicId, InputType? inputType, Language? language}); }
class UpdateVocabUseCase { const UpdateVocabUseCase(VocabRepository repo); Future<void> execute(VocabRecord); }
class DeleteVocabUseCase { const DeleteVocabUseCase(VocabRepository repo); Future<void> execute(String id); }
class GetTopicsUseCase { const GetTopicsUseCase(VocabRepository repo); Future<List<Topic>> execute(); }
class AddTopicUseCase { const AddTopicUseCase(VocabRepository repo); Future<Topic> execute({required String name, required String emoji}); }
class DeleteTopicUseCase { const DeleteTopicUseCase(VocabRepository repo); Future<void> execute(String topicId, {required bool isPredefined}); }
```

## Produces (used by Tasks 07, 09, 10)

```dart
// DI providers (accessible via ref.read/watch):
vocabRepositoryProvider    → VocabRepository
saveVocabUseCaseProvider   → SaveVocabUseCase
getVocabListUseCaseProvider → GetVocabListUseCase
updateVocabUseCaseProvider → UpdateVocabUseCase
deleteVocabUseCaseProvider → DeleteVocabUseCase
getTopicsUseCaseProvider   → GetTopicsUseCase
addTopicUseCaseProvider    → AddTopicUseCase
deleteTopicUseCaseProvider → DeleteTopicUseCase

// Notifiers:
vocabBankNotifierProvider   → AsyncValue<List<VocabRecord>>
  .notifier.save(VocabRecord)
  .notifier.update(VocabRecord)
  .notifier.delete(String)

topicsNotifierProvider      → AsyncValue<List<Topic>>
  .notifier.addTopic(String name, String emoji)
  .notifier.deleteTopic(String id, {required bool isPredefined})
```

## Steps

- [ ] **Step 1: Create vocab_bank_provider.dart**

```dart
// lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/vocab_record.dart';

part 'vocab_bank_provider.g.dart';

@riverpod
class VocabBankNotifier extends _$VocabBankNotifier {
  @override
  Future<List<VocabRecord>> build() =>
      ref.read(getVocabListUseCaseProvider).execute();

  Future<void> save(VocabRecord record) async {
    await ref.read(saveVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> update(VocabRecord record) async {
    await ref.read(updateVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(deleteVocabUseCaseProvider).execute(id);
    ref.invalidateSelf();
  }
}
```

- [ ] **Step 2: Create topics_provider.dart**

```dart
// lib/features/vocabulary/presentation/providers/topics_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/topic.dart';
import 'vocab_bank_provider.dart';

part 'topics_provider.g.dart';

@riverpod
class TopicsNotifier extends _$TopicsNotifier {
  @override
  Future<List<Topic>> build() =>
      ref.read(getTopicsUseCaseProvider).execute();

  Future<void> addTopic(String name, String emoji) async {
    await ref.read(addTopicUseCaseProvider).execute(name: name, emoji: emoji);
    ref.invalidateSelf();
  }

  Future<void> deleteTopic(String id, {required bool isPredefined}) async {
    await ref.read(deleteTopicUseCaseProvider).execute(id, isPredefined: isPredefined);
    ref.invalidateSelf();
    // Invalidate vocab list since words may have been reassigned
    ref.invalidate(vocabBankNotifierProvider);
  }
}
```

- [ ] **Step 3: Read the existing app_providers.dart**

Read `lib/core/di/app_providers.dart` to see what's already there (Plan 1 providers).

- [ ] **Step 4: Append vocab DI providers to app_providers.dart**

Add the following imports and providers to `lib/core/di/app_providers.dart` (keep all existing content, append at the end):

```dart
// --- Vocabulary DI (Plan 2) ---
import '../../features/vocabulary/data/repositories/vocab_repository_impl.dart';
import '../../features/vocabulary/domain/repositories/vocab_repository.dart';
import '../../features/vocabulary/domain/use_cases/add_topic_use_case.dart';
import '../../features/vocabulary/domain/use_cases/delete_topic_use_case.dart';
import '../../features/vocabulary/domain/use_cases/delete_vocab_use_case.dart';
import '../../features/vocabulary/domain/use_cases/get_topics_use_case.dart';
import '../../features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import '../../features/vocabulary/domain/use_cases/save_vocab_use_case.dart';
import '../../features/vocabulary/domain/use_cases/update_vocab_use_case.dart';

@riverpod
VocabRepository vocabRepository(VocabRepositoryRef ref) =>
    const VocabRepositoryImpl();

@riverpod
SaveVocabUseCase saveVocabUseCase(SaveVocabUseCaseRef ref) =>
    SaveVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
GetVocabListUseCase getVocabListUseCase(GetVocabListUseCaseRef ref) =>
    GetVocabListUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
UpdateVocabUseCase updateVocabUseCase(UpdateVocabUseCaseRef ref) =>
    UpdateVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
DeleteVocabUseCase deleteVocabUseCase(DeleteVocabUseCaseRef ref) =>
    DeleteVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
GetTopicsUseCase getTopicsUseCase(GetTopicsUseCaseRef ref) =>
    GetTopicsUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
AddTopicUseCase addTopicUseCase(AddTopicUseCaseRef ref) =>
    AddTopicUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
DeleteTopicUseCase deleteTopicUseCase(DeleteTopicUseCaseRef ref) =>
    DeleteTopicUseCase(ref.watch(vocabRepositoryProvider));
```

**Important:** The `@riverpod` annotation is already imported in `app_providers.dart` from Plan 1. Just add the new imports and providers.

- [ ] **Step 5: Run build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `.g.dart` files for both new provider files. No errors.

- [ ] **Step 6: Verify**

```bash
flutter analyze lib/features/vocabulary/presentation/providers/ lib/core/di/
```

Expected: no errors.

- [ ] **Step 7: Run tests**

```bash
flutter test
```

Expected: all existing tests still pass.

- [ ] **Step 8: Commit**

```bash
git add lib/features/vocabulary/presentation/providers/ \
        lib/core/di/app_providers.dart
git commit -m "feat(plan2): add VocabBankNotifier, TopicsNotifier, DI vocab providers"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: all pass
Analyze: no errors
Concerns: (if any)
