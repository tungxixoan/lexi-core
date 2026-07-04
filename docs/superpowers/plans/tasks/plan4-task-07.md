# Plan 4 — Task 07: SyncService + SyncNotifier

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 02 (UserSettingsState + sharedPreferencesProvider), Task 06 (authNotifierProvider)

## What this task builds

- `SyncService`: plain Dart class — batch-pushes local Hive data to Firestore on sign-in, then maintains bidirectional sync via Hive.watch() ↔ Firestore snapshots. Includes loop-prevention to stop Firestore→Hive writes from echoing back to Firestore.
- `SyncNotifier`: Riverpod notifier that watches `authNotifierProvider` and starts/stops `SyncService`.
- 2 unit tests (construction + idempotent stopSync).

## Files

- Create: `lib/core/services/sync_service.dart`
- Create: `lib/features/settings/presentation/providers/sync_notifier.dart`
- Generated: `lib/features/settings/presentation/providers/sync_notifier.g.dart`
- Create: `test/core/services/sync_service_test.dart`

## Interfaces consumed

```dart
// authNotifierProvider  — AsyncValue<User?> from Task 06
// userSettingsNotifierProvider  — UserSettingsState from Task 02
// UserSettingsState.targetLanguage.name, .activeContext.name, .aiEnabled, .targetCefrLevel?.name
// Hive.box<String>('vocab_records') — already open in main.dart
// Hive.box<String>('topics')        — already open in main.dart
// VocabRecord.toJson() / fromJson() — on VocabRecord entity
// dart:developer (log)
// cloud_firestore: FirebaseFirestore, CollectionReference, DocumentChangeType
// hive: Box<String>, BoxEvent, StreamSubscription
```

## Interfaces produced

```dart
enum SyncStatus { idle, syncing, error }

class SyncService {
  SyncService({required Box<String> vocabBox, required Box<String> topicsBox});
  Future<void> startSync(String uid, UserSettingsState settings,
      void Function(SyncStatus) onStatus);
  void stopSync();
}

// syncNotifierProvider: NotifierProvider<SyncNotifier, SyncStatus>
// SyncStatus state — used by SettingsScreen (Task 08) to show sync indicator
```

---

- [ ] **Step 1: Write the failing test**

Create `test/core/services/sync_service_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lexi_core/core/services/sync_service.dart';

void main() {
  late Box<String> vocabBox;
  late Box<String> topicsBox;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_test');
    Hive.init(tempDir.path);
    vocabBox = await Hive.openBox<String>('vocab_test_${DateTime.now().millisecondsSinceEpoch}');
    topicsBox = await Hive.openBox<String>('topics_test_${DateTime.now().millisecondsSinceEpoch}');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('SyncService can be created without error', () {
    final service = SyncService(vocabBox: vocabBox, topicsBox: topicsBox);
    expect(service, isNotNull);
  });

  test('stopSync() is safe to call before startSync()', () {
    final service = SyncService(vocabBox: vocabBox, topicsBox: topicsBox);
    expect(() => service.stopSync(), returnsNormally);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/core/services/sync_service_test.dart
```

Expected: FAIL — `SyncService` is not defined yet.

- [ ] **Step 3: Create SyncService**

Create `lib/core/services/sync_service.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../../features/dictionary/domain/entities/user_settings_state.dart';

enum SyncStatus { idle, syncing, error }

class SyncService {
  SyncService({required this.vocabBox, required this.topicsBox});

  final Box<String> vocabBox;
  final Box<String> topicsBox;

  // Keys being written from Firestore → Hive — prevents echo back to Firestore
  final _firestoreUpdatingVocab = <String>{};
  final _firestoreUpdatingTopic = <String>{};

  StreamSubscription? _vocabHiveSub;
  StreamSubscription? _topicHiveSub;
  StreamSubscription? _firestoreVocabSub;
  StreamSubscription? _firestoreTopicSub;

  Future<void> startSync(
    String uid,
    UserSettingsState settings,
    void Function(SyncStatus) onStatus,
  ) async {
    final db = FirebaseFirestore.instance;
    final vocabCol = db.collection('users').doc(uid).collection('vocab_records');
    final topicsCol = db.collection('users').doc(uid).collection('topics');
    final userDoc = db.collection('users').doc(uid);

    onStatus(SyncStatus.syncing);

    try {
      // Batch-push all local vocab to Firestore (local is authoritative at sign-in)
      var batch = db.batch();
      var count = 0;

      for (final raw in vocabBox.values) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        batch.set(vocabCol.doc(map['id'] as String), map);
        count++;
        if (count == 500) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      // Batch-push all local topics
      for (final raw in topicsBox.values) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        batch.set(topicsCol.doc(map['id'] as String), map);
        count++;
        if (count == 500) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      // Push settings doc (NEVER include geminiApiKey)
      batch.set(userDoc, {
        'targetLanguage': settings.targetLanguage.name,
        'activeContext': settings.activeContext.name,
        'aiEnabled': settings.aiEnabled,
        if (settings.targetCefrLevel != null)
          'targetCefrLevel': settings.targetCefrLevel!.name,
      });

      if (count > 0) await batch.commit();
    } catch (e) {
      dev.log('SyncService: initial push failed: $e');
      onStatus(SyncStatus.error);
      return;
    }

    // Subscribe: Firestore vocab → Hive (remote updates local if newer)
    _firestoreVocabSub = vocabCol.snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _firestoreUpdatingVocab.add(id);
            vocabBox.delete(id).then((_) => _firestoreUpdatingVocab.remove(id));
          } else {
            final remoteMap = change.doc.data()!;
            final localRaw = vocabBox.get(id);
            bool shouldUpdate;
            if (localRaw == null) {
              shouldUpdate = true;
            } else {
              final localMap = jsonDecode(localRaw) as Map<String, dynamic>;
              final remoteUpdatedAt =
                  DateTime.parse(remoteMap['updatedAt'] as String);
              final localUpdatedAt =
                  DateTime.parse(localMap['updatedAt'] as String);
              shouldUpdate = remoteUpdatedAt.isAfter(localUpdatedAt);
            }
            if (shouldUpdate) {
              _firestoreUpdatingVocab.add(id);
              vocabBox.put(id, jsonEncode(remoteMap)).then((_) {
                _firestoreUpdatingVocab.remove(id);
              }).catchError((e) {
                _firestoreUpdatingVocab.remove(id);
                dev.log('SyncService: Hive vocab write failed: $e');
              });
            }
          }
        }
      },
      onError: (e) => dev.log('SyncService: Firestore vocab stream error: $e'),
    );

    // Subscribe: Hive vocab → Firestore (skip keys being written from Firestore)
    _vocabHiveSub = vocabBox.watch().listen((event) {
      final key = event.key as String;
      if (_firestoreUpdatingVocab.contains(key)) return;
      if (event.deleted) {
        vocabCol.doc(key).delete().catchError(
            (e) => dev.log('SyncService: Firestore vocab delete failed: $e'));
      } else {
        final map =
            jsonDecode(event.value as String) as Map<String, dynamic>;
        vocabCol.doc(key).set(map).catchError(
            (e) => dev.log('SyncService: Firestore vocab write failed: $e'));
      }
    });

    // Subscribe: Firestore topics → Hive (remote wins if not in local)
    _firestoreTopicSub = topicsCol.snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _firestoreUpdatingTopic.add(id);
            topicsBox.delete(id).then((_) => _firestoreUpdatingTopic.remove(id));
          } else {
            final localRaw = topicsBox.get(id);
            if (localRaw == null) {
              // Only add topics that don't exist locally (topics have no updatedAt)
              _firestoreUpdatingTopic.add(id);
              topicsBox
                  .put(id, jsonEncode(change.doc.data()))
                  .then((_) => _firestoreUpdatingTopic.remove(id))
                  .catchError((e) => _firestoreUpdatingTopic.remove(id));
            }
          }
        }
      },
      onError: (e) => dev.log('SyncService: Firestore topics stream error: $e'),
    );

    // Subscribe: Hive topics → Firestore
    _topicHiveSub = topicsBox.watch().listen((event) {
      final key = event.key as String;
      if (_firestoreUpdatingTopic.contains(key)) return;
      if (event.deleted) {
        topicsCol.doc(key).delete().catchError(
            (e) => dev.log('SyncService: Firestore topic delete failed: $e'));
      } else {
        final map =
            jsonDecode(event.value as String) as Map<String, dynamic>;
        topicsCol.doc(key).set(map).catchError(
            (e) => dev.log('SyncService: Firestore topic write failed: $e'));
      }
    });

    onStatus(SyncStatus.idle);
  }

  void stopSync() {
    _vocabHiveSub?.cancel();
    _topicHiveSub?.cancel();
    _firestoreVocabSub?.cancel();
    _firestoreTopicSub?.cancel();
    _vocabHiveSub = null;
    _topicHiveSub = null;
    _firestoreVocabSub = null;
    _firestoreTopicSub = null;
    _firestoreUpdatingVocab.clear();
    _firestoreUpdatingTopic.clear();
  }
}
```

- [ ] **Step 4: Create SyncNotifier**

Create `lib/features/settings/presentation/providers/sync_notifier.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import 'auth_notifier.dart';

part 'sync_notifier.g.dart';

@Riverpod(keepAlive: true)
class SyncNotifier extends _$SyncNotifier {
  SyncService? _service;

  @override
  SyncStatus build() {
    ref.listen<AsyncValue<User?>>(authNotifierProvider, (_, next) {
      final user = next.valueOrNull;
      if (user != null) {
        _startSync(user.uid);
      } else {
        _stopSync();
      }
    });
    return SyncStatus.idle;
  }

  Future<void> _startSync(String uid) async {
    _service?.stopSync();
    _service = SyncService(
      vocabBox: Hive.box<String>('vocab_records'),
      topicsBox: Hive.box<String>('topics'),
    );
    final settings = ref.read(userSettingsNotifierProvider);
    await _service!.startSync(uid, settings, (status) => state = status);
  }

  void _stopSync() {
    _service?.stopSync();
    _service = null;
    state = SyncStatus.idle;
  }
}
```

- [ ] **Step 5: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `sync_notifier.g.dart` generated.

- [ ] **Step 6: Run tests**

```
flutter test test/core/services/sync_service_test.dart
```

Expected: 2/2 PASS.

- [ ] **Step 7: Run full suite and analyze**

```
flutter test
flutter analyze lib/
```

Expected: all passing, no errors.

- [ ] **Step 8: Commit**

```
git add lib/core/services/sync_service.dart lib/features/settings/presentation/providers/sync_notifier.dart lib/features/settings/presentation/providers/sync_notifier.g.dart test/core/services/sync_service_test.dart
git commit -m "feat(plan4): add SyncService and SyncNotifier for Firestore bidirectional sync"
```

## Self-review checklist

- [ ] `geminiApiKey` is NOT written to the Firestore settings doc
- [ ] Loop prevention: `_firestoreUpdatingVocab.add(id)` before `vocabBox.put()`, `.remove(id)` after — Hive watcher checks this set before pushing to Firestore
- [ ] `stopSync()` cancels ALL 4 subscriptions and clears both Sets
- [ ] `stopSync()` is safe to call when subscriptions are null (null-safe cancel)
- [ ] Initial batch commit only called when `count > 0` (empty box = no commit)
- [ ] Batch limit of 500 per commit (Firestore hard limit is 500 writes per batch)
- [ ] `SyncNotifier` is `@Riverpod(keepAlive: true)` 
- [ ] `SyncNotifier.build()` uses `ref.listen` (not `ref.watch`) for auth changes
- [ ] `_startSync` uses `ref.read(userSettingsNotifierProvider)` (not ref.watch — called from listener)
- [ ] 2/2 unit tests pass
- [ ] Full suite passes
