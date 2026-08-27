# Flutter: Drop Hive, Firestore-Direct + Mandatory Sign-In Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Hive as Flutter's vocab/topics data store entirely — read/write Firestore directly (exactly like `apps/web/` already does), require sign-in to use the app, and safely migrate any existing offline-only users' local data to Firestore on their first post-update sign-in.

**Architecture:** `VocabRepositoryImpl` is rewritten against Firestore behind its existing, unchanged `VocabRepository` interface, so every consumer that already goes through that interface needs no changes. `StatsService`'s `computeStats()` becomes async (reads via the repository instead of a Hive box), rippling through its 3 direct call sites. `sync_service.dart`/`sync_notifier.dart` are deleted outright — there's nothing left to keep in sync once Firestore is the only store. A new router-level redirect makes sign-in mandatory app-wide, backed by a small one-time migration that pushes any pre-existing local Hive data to Firestore on first sign-in before Hive is abandoned.

**Tech Stack:** Flutter, Riverpod (riverpod_generator), GoRouter, Cloud Firestore, `fake_cloud_firestore` (new test dependency).

## Global Constraints

- Mandatory sign-in: every screen requires a signed-in user (matches `apps/web/`'s existing behavior). No offline/guest mode remains.
- `VocabRepository`'s abstract interface (`save`, `getAll`, `getById`, `update`, `delete`, `existsByHeadword`, `getByHeadword`, `getTopics`, `addTopic`, `deleteTopic`) does not change — only its implementation.
- Firestore paths: `users/{uid}/vocab_records`, `users/{uid}/topics` — same paths the web app already uses, same document shape (`VocabRecord.toJson()`/`fromJson()`, `Topic.toJson()`/`fromJson()` already exist and are reused as-is).
- `getTopics()` seeds `Topic.predefined` (20 fixed topics) into Firestore on first call if the collection is empty — ports the existing Hive-based seed-on-empty behavior exactly.
- Async-computation failures (notification scheduling, progress stats) are best-effort: caught, no crash, silently skip that cycle, retry next trigger — accepted tradeoff, does not apply to the one-time Hive→Firestore migration (see Task 4), which must show an explicit error + retry on failure since it touches irreplaceable local-only data.
- No new Cloud Function, no change to `apps/web/`.

---

## Task 1: `VocabRepositoryImpl` — Firestore-backed

**Files:**
- Modify: `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`
- Create: `test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart`
- Modify: `pubspec.yaml` (add `fake_cloud_firestore` to `dev_dependencies`)

**Interfaces:**
- Consumes: `VocabRecord.toJson()`/`.fromJson()` (existing, unchanged, in `lib/features/vocabulary/domain/entities/vocab_record.dart`), `Topic.toJson()`/`.fromJson()`/`.predefined` (existing, unchanged, in `lib/features/vocabulary/domain/entities/topic.dart`), `VocabRepository` abstract interface (existing, unchanged, in `lib/features/vocabulary/domain/repositories/vocab_repository.dart`).
- Produces: `VocabRepositoryImpl` now takes a required `uid` and a `FirebaseFirestore` instance in its constructor (`VocabRepositoryImpl({required String uid, FirebaseFirestore? firestore})` — `firestore` optional/defaulted to `FirebaseFirestore.instance` so tests can inject a fake). Task 4 (DI wiring in `app_providers.dart`) constructs it with the signed-in user's `uid`.

- [ ] **Step 1: Add the test dependency**

In `pubspec.yaml`, under `dev_dependencies:`, add:
```yaml
  fake_cloud_firestore: ^3.1.0
```
Run: `flutter pub get`
Expected: resolves cleanly, no version conflicts.

- [ ] **Step 2: Write the failing tests**

```dart
// test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/data/repositories/vocab_repository_impl.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';

VocabRecord _record({
  required String id,
  String headword = 'test',
  Language language = Language.english,
  CEFRLevel cefr = CEFRLevel.b1,
  List<String> topicIds = const [],
  DateTime? createdAt,
}) =>
    VocabRecord(
      id: id,
      headword: headword,
      inputType: InputType.word,
      ipa: '',
      meaning: 'nghĩa',
      examples: const [],
      personalNotes: '',
      topicIds: topicIds,
      targetLanguage: language,
      cefrLevel: cefr,
      activeContext: AppContext.general,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      updatedAt: createdAt ?? DateTime(2026, 1, 1),
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late VocabRepositoryImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = VocabRepositoryImpl(uid: 'u1', firestore: firestore);
  });

  test('save() writes to users/u1/vocab_records/{id}', () async {
    await repo.save(_record(id: 'v1', headword: 'apple'));
    final doc =
        await firestore.collection('users/u1/vocab_records').doc('v1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['headword'], 'apple');
  });

  test('getAll() returns all records for this user, newest first', () async {
    await repo.save(_record(id: 'v1', createdAt: DateTime(2026, 1, 1)));
    await repo.save(_record(id: 'v2', createdAt: DateTime(2026, 1, 5)));
    final all = await repo.getAll();
    expect(all.map((r) => r.id).toList(), ['v2', 'v1']);
  });

  test('getAll() filters by language when given', () async {
    await repo.save(_record(id: 'v1', language: Language.english));
    await repo.save(_record(id: 'v2', language: Language.chinese));
    final all = await repo.getAll(language: Language.chinese);
    expect(all.map((r) => r.id).toList(), ['v2']);
  });

  test('getAll() filters by topicId when given', () async {
    await repo.save(_record(id: 'v1', topicIds: ['travel']));
    await repo.save(_record(id: 'v2', topicIds: ['business']));
    final all = await repo.getAll(topicId: 'travel');
    expect(all.map((r) => r.id).toList(), ['v1']);
  });

  test('getAll() filters by maxCefrLevel when given', () async {
    await repo.save(_record(id: 'v1', cefr: CEFRLevel.a1));
    await repo.save(_record(id: 'v2', cefr: CEFRLevel.c2));
    final all = await repo.getAll(maxCefrLevel: CEFRLevel.b1);
    expect(all.map((r) => r.id).toList(), ['v1']);
  });

  test('getById() returns the matching record or null', () async {
    await repo.save(_record(id: 'v1', headword: 'apple'));
    expect((await repo.getById('v1'))?.headword, 'apple');
    expect(await repo.getById('missing'), isNull);
  });

  test('update() overwrites the stored record', () async {
    await repo.save(_record(id: 'v1', headword: 'apple'));
    final updated = _record(id: 'v1', headword: 'banana');
    await repo.update(updated);
    expect((await repo.getById('v1'))?.headword, 'banana');
  });

  test('delete() removes the record', () async {
    await repo.save(_record(id: 'v1'));
    await repo.delete('v1');
    expect(await repo.getById('v1'), isNull);
  });

  test('existsByHeadword() is case-insensitive and language-scoped', () async {
    await repo.save(_record(id: 'v1', headword: 'Apple', language: Language.english));
    expect(await repo.existsByHeadword('apple', Language.english), isTrue);
    expect(await repo.existsByHeadword('apple', Language.chinese), isFalse);
  });

  test('getByHeadword() returns the matching record case-insensitively', () async {
    await repo.save(_record(id: 'v1', headword: 'Apple', language: Language.english));
    expect((await repo.getByHeadword('apple', Language.english))?.id, 'v1');
    expect(await repo.getByHeadword('nope', Language.english), isNull);
  });

  test('getTopics() seeds the 20 predefined topics into Firestore on first call when empty', () async {
    final topics = await repo.getTopics();
    expect(topics.length, 20);
    final stored = await firestore.collection('users/u1/topics').get();
    expect(stored.docs.length, 20);
  });

  test('getTopics() predefined-first then alphabetical, and does not reseed twice', () async {
    final first = await repo.getTopics();
    expect(first.length, 20);
    await repo.addTopic(Topic(
      id: 'custom1',
      name: 'Aardvarks',
      emoji: '🎯',
      isPredefined: false,
      createdAt: DateTime(2026, 2, 1),
    ));
    final second = await repo.getTopics();
    expect(second.length, 21);
    expect(second.first.isPredefined, isTrue);
    expect(second.last.name, 'Aardvarks');
  });

  test('deleteTopic() reassigns affected words to "other" and removes the topic', () async {
    await repo.getTopics();
    await repo.addTopic(Topic(
      id: 'custom1',
      name: 'Custom',
      emoji: '🎯',
      isPredefined: false,
      createdAt: DateTime(2026, 2, 1),
    ));
    await repo.save(_record(id: 'v1', topicIds: ['custom1']));
    await repo.deleteTopic('custom1');
    final record = await repo.getById('v1');
    expect(record!.topicIds, ['other']);
    final topics = await repo.getTopics();
    expect(topics.any((t) => t.id == 'custom1'), isFalse);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart`
Expected: FAIL — `VocabRepositoryImpl` doesn't yet accept `uid`/`firestore` constructor params (compile error).

- [ ] **Step 4: Implement `VocabRepositoryImpl`**

Replace the entire contents of `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`:

```dart
// lib/features/vocabulary/data/repositories/vocab_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/cefr_level.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/vocab_record.dart';
import '../../domain/repositories/vocab_repository.dart';
import '../../../../features/dictionary/domain/entities/input_type.dart';
import '../../../../features/dictionary/domain/entities/language.dart';

class VocabRepositoryImpl implements VocabRepository {
  VocabRepositoryImpl({required this.uid, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _vocabCol =>
      _firestore.collection('users').doc(uid).collection('vocab_records');
  CollectionReference<Map<String, dynamic>> get _topicsCol =>
      _firestore.collection('users').doc(uid).collection('topics');

  @override
  Future<void> save(VocabRecord record) async {
    await _vocabCol.doc(record.id).set(record.toJson());
  }

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async {
    final snapshot = await _vocabCol.get();
    var records =
        snapshot.docs.map((d) => VocabRecord.fromJson(d.data())).toList();
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

  @override
  Future<VocabRecord?> getById(String id) async {
    final doc = await _vocabCol.doc(id).get();
    if (!doc.exists) return null;
    return VocabRecord.fromJson(doc.data()!);
  }

  @override
  Future<void> update(VocabRecord record) async {
    await _vocabCol.doc(record.id).set(record.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _vocabCol.doc(id).delete();
  }

  @override
  Future<bool> existsByHeadword(String headword, Language language) async {
    return await getByHeadword(headword, language) != null;
  }

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async {
    final lc = headword.toLowerCase();
    final snapshot =
        await _vocabCol.where('targetLanguage', isEqualTo: language.name).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if ((data['headword'] as String).toLowerCase() == lc) {
        return VocabRecord.fromJson(data);
      }
    }
    return null;
  }

  @override
  Future<List<Topic>> getTopics() async {
    var snapshot = await _topicsCol.get();
    if (snapshot.docs.isEmpty) {
      await _seedTopics();
      snapshot = await _topicsCol.get();
    }
    final topics = snapshot.docs.map((d) => Topic.fromJson(d.data())).toList();
    topics.sort((a, b) {
      if (a.isPredefined && !b.isPredefined) return -1;
      if (!a.isPredefined && b.isPredefined) return 1;
      return a.name.compareTo(b.name);
    });
    return topics;
  }

  @override
  Future<void> addTopic(Topic topic) async {
    await _topicsCol.doc(topic.id).set(topic.toJson());
  }

  @override
  Future<void> deleteTopic(String id) async {
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
    await _topicsCol.doc(id).delete();
  }

  Future<void> _seedTopics() async {
    final batch = _firestore.batch();
    for (final topic in Topic.predefined) {
      batch.set(_topicsCol.doc(topic.id), topic.toJson());
    }
    await batch.commit();
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart`
Expected: PASS, 13/13.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/vocabulary/data/repositories/vocab_repository_impl.dart test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart
git commit -m "feat: rewrite VocabRepositoryImpl against Firestore instead of Hive"
```

---

## Task 2: `StatsService` + `GetLearningStatsUseCase` + notification scheduling — async

**Files:**
- Modify: `lib/core/services/stats_service.dart`
- Modify: `test/core/services/stats_service_test.dart`
- Modify: `lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart`
- Modify: `lib/features/practice/presentation/providers/notification_notifier.dart`
- Modify: `lib/core/di/app_providers.dart`

**Interfaces:**
- Consumes: `VocabRepositoryImpl` (Task 1), `VocabRepository` abstract interface.
- Produces: `StatsService.computeStats()` is now `Future<LearningStats>` (was sync `LearningStats`). `GetLearningStatsUseCase.execute()` is now `Future<LearningStats>`. Task 3 consumes both of these as async.

- [ ] **Step 1: Update the failing/changed tests**

Rewrite `test/core/services/stats_service_test.dart` in full — it currently constructs `StatsService` with a raw Hive `Box<String>`; it must construct it with a `VocabRepository` fake instead, and every `computeStats()` call must be `await`ed:

```dart
// test/core/services/stats_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<void> save(VocabRecord record) async {}
  @override
  Future<VocabRecord?> getById(String id) async => null;
  @override
  Future<void> update(VocabRecord record) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<bool> existsByHeadword(String headword, Language language) async => false;
  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async => null;
  @override
  Future<List<Topic>> getTopics() async => [];
  @override
  Future<void> addTopic(Topic topic) async {}
  @override
  Future<void> deleteTopic(String id) async {}
}

VocabRecord _record(String id, {int sm2Interval = 1, DateTime? nextReviewAt, CEFRLevel cefr = CEFRLevel.b1}) =>
    VocabRecord(
      id: id,
      headword: 'w$id',
      inputType: InputType.word,
      ipa: '',
      meaning: 'x',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: cefr,
      activeContext: AppContext.general,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      sm2Interval: sm2Interval,
      nextReviewAt: nextReviewAt,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('computeStats() returns zeros when there are no records', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StatsService(repository: _FakeVocabRepository([]), prefs: prefs);
    final stats = await service.computeStats();
    expect(stats.dueCount, 0);
    expect(stats.masteredCount, 0);
    expect(stats.totalCount, 0);
    expect(stats.currentStreak, 0);
    expect(stats.weeklyLog, isEmpty);
  });

  test('computeStats() correctly counts due and mastered words', () async {
    final prefs = await SharedPreferences.getInstance();
    final records = [
      _record('1', nextReviewAt: null), // due: no next review yet
      _record('2', nextReviewAt: DateTime.now().subtract(const Duration(days: 1))), // due: past
      _record('3', nextReviewAt: DateTime.now().add(const Duration(days: 5))), // not due
      _record('4', sm2Interval: 25), // mastered
      _record('5', sm2Interval: 3), // not mastered
    ];
    final service = StatsService(repository: _FakeVocabRepository(records), prefs: prefs);
    final stats = await service.computeStats();
    expect(stats.dueCount, 2);
    expect(stats.masteredCount, 1);
    expect(stats.totalCount, 5);
  });

  test('computeStats() builds a CEFR breakdown across all 6 levels', () async {
    final prefs = await SharedPreferences.getInstance();
    final records = [
      _record('1', cefr: CEFRLevel.a1),
      _record('2', cefr: CEFRLevel.a1),
      _record('3', cefr: CEFRLevel.c2),
    ];
    final service = StatsService(repository: _FakeVocabRepository(records), prefs: prefs);
    final stats = await service.computeStats();
    expect(stats.cefrBreakdown[CEFRLevel.a1], 2);
    expect(stats.cefrBreakdown[CEFRLevel.c2], 1);
    expect(stats.cefrBreakdown[CEFRLevel.b1], 0);
  });

  test('recordPracticeSession() same-day repeat call does not bump streak but accumulates the log', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StatsService(repository: _FakeVocabRepository([]), prefs: prefs);
    await service.recordPracticeSession(5);
    await service.recordPracticeSession(3);
    final stats = await service.computeStats();
    expect(stats.currentStreak, 1);
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    expect(stats.weeklyLog[todayKey], 8);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/stats_service_test.dart`
Expected: FAIL — `StatsService` doesn't yet accept a `repository:` named param (compile error), `computeStats()` isn't awaitable yet in the old signature.

- [ ] **Step 3: Implement the changes**

Replace `lib/core/services/stats_service.dart`'s constructor and `computeStats()` — everything else (the `recordPracticeSession`/`_dateKey` SharedPreferences logic) is unchanged:

```dart
// lib/core/services/stats_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/practice/domain/entities/learning_stats.dart';
import '../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../features/vocabulary/domain/repositories/vocab_repository.dart';

class StatsService {
  StatsService({required this.repository, required this.prefs});

  final VocabRepository repository;
  final SharedPreferences prefs;

  Future<LearningStats> computeStats() async {
    final now = DateTime.now();
    final records = await repository.getAll();

    int dueCount = 0;
    int masteredCount = 0;
    final cefrBreakdown = {for (final l in CEFRLevel.values) l: 0};

    for (final r in records) {
      if (r.nextReviewAt == null || r.nextReviewAt!.isBefore(now)) dueCount++;
      if (r.sm2Interval >= 21) masteredCount++;
      cefrBreakdown[r.cefrLevel] = (cefrBreakdown[r.cefrLevel] ?? 0) + 1;
    }

    final currentStreak = prefs.getInt('current_streak') ?? 0;
    final logJson = prefs.getString('weekly_review_log') ?? '{}';
    final logRaw = jsonDecode(logJson) as Map<String, dynamic>;
    final weeklyLog = logRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    return LearningStats(
      dueCount: dueCount,
      masteredCount: masteredCount,
      totalCount: records.length,
      cefrBreakdown: cefrBreakdown,
      currentStreak: currentStreak,
      weeklyLog: weeklyLog,
    );
  }

  Future<void> recordPracticeSession(int wordCount) async {
    final today = _dateKey(DateTime.now());
    final yesterday =
        _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    final lastDate = prefs.getString('last_practiced_date') ?? '';

    final int newStreak;
    if (lastDate == today) {
      newStreak = prefs.getInt('current_streak') ?? 1;
    } else if (lastDate == yesterday) {
      newStreak = (prefs.getInt('current_streak') ?? 0) + 1;
    } else {
      newStreak = 1;
    }

    await prefs.setString('last_practiced_date', today);
    await prefs.setInt('current_streak', newStreak);

    final logJson = prefs.getString('weekly_review_log') ?? '{}';
    final log = Map<String, int>.from(
      (jsonDecode(logJson) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
    log[today] = (log[today] ?? 0) + wordCount;

    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final cutoffKey = _dateKey(DateTime(cutoff.year, cutoff.month, cutoff.day));
    log.removeWhere((k, _) => k.compareTo(cutoffKey) < 0);

    await prefs.setString('weekly_review_log', jsonEncode(log));
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
```

In `lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart`, change `execute()` to be async:

```dart
import '../../../../core/services/stats_service.dart';
import '../entities/learning_stats.dart';

class GetLearningStatsUseCase {
  const GetLearningStatsUseCase(this._statsService);
  final StatsService _statsService;

  Future<LearningStats> execute() => _statsService.computeStats();
}
```

In `lib/features/practice/presentation/providers/notification_notifier.dart`, replace `_computeNextDueAt()` with an async version that goes through `GetLearningStatsUseCase`'s companion — actually the due-date lookup needs the raw records, not aggregate stats, so it goes through the repository directly instead of `getLearningStatsUseCaseProvider`. Replace this method:

```dart
  Future<DateTime?> _computeNextDueAt() async {
    final records = await ref.read(vocabRepositoryProvider).getAll();
    final now = DateTime.now();
    DateTime? earliest;
    for (final r in records) {
      final nextReviewAt = r.nextReviewAt;
      if (nextReviewAt == null) continue;
      if (nextReviewAt.isAfter(now)) {
        if (earliest == null || nextReviewAt.isBefore(earliest)) {
          earliest = nextReviewAt;
        }
      }
    }
    return earliest;
  }
```

And update `reschedule()` (already `async`) to await both calls that changed:

```dart
  Future<void> reschedule() async {
    if (kIsWeb) return;
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.reminderEnabled) {
      await _service.cancelAll();
      return;
    }
    final stats = await ref.read(getLearningStatsUseCaseProvider).execute();
    final nextDueAt = await _computeNextDueAt();
    await _service.scheduleAll(
      enabled: settings.reminderEnabled,
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      dueCount: stats.dueCount,
      nextDueAt: nextDueAt,
    );
  }
```

Remove the now-unused `import 'package:hive/hive.dart';` from this file if it's no longer referenced elsewhere in it (check after the edit — it won't be, since `_computeNextDueAt` no longer touches `Hive.box`).

In `lib/core/di/app_providers.dart`, replace the `statsService` provider (remove the `Hive.box` reference) — find:
```dart
@riverpod
StatsService statsService(StatsServiceRef ref) => StatsService(
      vocabBox: Hive.box<String>('vocab_records'),
      prefs: ref.read(sharedPreferencesProvider),
    );
```
with:
```dart
@riverpod
StatsService statsService(StatsServiceRef ref) => StatsService(
      repository: ref.watch(vocabRepositoryProvider),
      prefs: ref.read(sharedPreferencesProvider),
    );
```
(`vocabRepositoryProvider` is defined in this same file — Task 4 updates it to construct `VocabRepositoryImpl` with the signed-in `uid`; for this task, it's fine if it still constructs the repository the way it already does today, since this task only changes what `StatsService` is given, not how the repository itself is built.)

If `import 'package:hive/hive.dart';` becomes unused in `app_providers.dart` after this change, remove it (check — `hive_flutter`/`Hive.box<String>('vocab_records')` may still be referenced elsewhere in this same file for the `vocabRepositoryProvider` itself; leave that import in place if so — Task 4 removes it when `vocabRepositoryProvider` itself stops using Hive).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/stats_service_test.dart`
Expected: PASS, 4/4.

- [ ] **Step 5: Run `flutter analyze` to catch any remaining sync-call-site compile errors**

Run: `flutter analyze`
Expected: errors remain in `lib/features/practice/presentation/screens/progress_screen.dart` and `lib/features/practice/presentation/screens/practice_home_screen.dart` (both still call `computeStats()`/read `learningStatsProvider` synchronously) — this is expected; Task 3 fixes them. Confirm no OTHER unexpected errors appear.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/stats_service.dart test/core/services/stats_service_test.dart lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart lib/features/practice/presentation/providers/notification_notifier.dart lib/core/di/app_providers.dart
git commit -m "feat: make StatsService.computeStats() and notification scheduling async"
```

Note: this commit leaves `progress_screen.dart` and `practice_home_screen.dart` non-compiling until Task 3 — expected, fixed in the very next task.

---

## Task 3: Async-aware UI — progress screen + practice home screen

**Files:**
- Modify: `lib/features/practice/presentation/screens/progress_screen.dart`
- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart`
- Modify: `lib/core/di/app_providers.dart` (the `learningStats` provider itself)

**Interfaces:**
- Consumes: `StatsService.computeStats()` returning `Future<LearningStats>` (Task 2).
- Produces: nothing new consumed by later tasks.

- [ ] **Step 1: Update `learningStats` provider to be async**

In `lib/core/di/app_providers.dart`, find:
```dart
@riverpod
LearningStats learningStats(LearningStatsRef ref) =>
    ref.watch(statsServiceProvider).computeStats();
```
Replace with:
```dart
@riverpod
Future<LearningStats> learningStats(LearningStatsRef ref) =>
    ref.watch(statsServiceProvider).computeStats();
```
(`riverpod_generator` auto-detects a `Future<T>`-returning function and generates an `AsyncValue<T>`-based provider — same pattern already used by `topics_provider.dart`'s `Future<List<Topic>> build()`.)

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `app_providers.g.dart` with `learningStatsProvider` now typed as `AutoDisposeFutureProvider<LearningStats>` (or equivalent — check the generated file compiles).

- [ ] **Step 2: Read the current `progress_screen.dart` and update its consumption**

Read `lib/features/practice/presentation/screens/progress_screen.dart` in full first. It currently does `final stats = ref.watch(learningStatsProvider);` and uses `stats` directly (a bare `LearningStats`). Change this line to:
```dart
final statsAsync = ref.watch(learningStatsProvider);
```
Then wrap the body of the `build()` method (whatever currently renders using `stats`) in:
```dart
return statsAsync.when(
  loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
  error: (e, _) => Scaffold(
    appBar: AppBar(title: const Text('Tiến độ học tập')),
    body: const Center(child: Text('Không tải được dữ liệu tiến độ.')),
  ),
  data: (stats) {
    // ...the screen's existing body, unchanged, using `stats` exactly as before...
  },
);
```
Keep every existing widget/layout line inside the `data:` branch exactly as it was — only the outer wrapping changes. Match this app's existing Scaffold/AppBar structure for this screen (read the file to get the exact `AppBar` title and `Scaffold` structure right, so the loading/error states use the same chrome as the real screen rather than a bare generic one).

- [ ] **Step 3: Update `practice_home_screen.dart`'s due-count badge**

In `lib/features/practice/presentation/screens/practice_home_screen.dart`, find:
```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(userSettingsNotifierProvider);
      final stats = ref.read(statsServiceProvider).computeStats();
      setState(() {
        _maxCefrLevel = settings.targetCefrLevel;
        _dueCount = stats.dueCount;
      });
    });
```
Replace with:
```dart
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final settings = ref.read(userSettingsNotifierProvider);
      setState(() => _maxCefrLevel = settings.targetCefrLevel);
      try {
        final stats = await ref.read(statsServiceProvider).computeStats();
        if (!mounted) return;
        setState(() => _dueCount = stats.dueCount);
      } catch (_) {
        // Best-effort: leave _dueCount at its initial 0 on failure.
      }
    });
```
`_dueCount`'s existing initial value (`0`) already serves as the loading/error placeholder — no new state field needed.

- [ ] **Step 4: Run `flutter analyze` and the full test suite**

Run: `flutter analyze`
Expected: clean, no errors.

Run: `flutter test`
Expected: all tests pass. If any unrelated failures appear, re-run those specific files in isolation before concluding they're a real regression.

- [ ] **Step 5: Commit**

```bash
git add lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart lib/features/practice/presentation/screens/progress_screen.dart lib/features/practice/presentation/screens/practice_home_screen.dart
git commit -m "feat: make progress screen and practice home due-count badge async-aware"
```

---

## Task 4: Mandatory sign-in + one-time Hive→Firestore migration

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Create: `lib/features/settings/presentation/screens/sign_in_screen.dart`
- Create: `lib/core/services/hive_migration_service.dart`
- Create: `test/core/services/hive_migration_service_test.dart`
- Create: `test/core/router/auth_redirect_test.dart`

**Interfaces:**
- Consumes: `AuthNotifier`/`authNotifierProvider` (existing, unchanged, `lib/features/settings/presentation/providers/auth_notifier.dart` — `signInWithGoogle()`, `Stream<User?> build()`).
- Produces: `/sign-in` and `/splash` top-level routes. `authRedirectDecision({matchedLocation, hasResolved, signedIn})` (exported from `app_router.dart`) — a pure function, not consumed elsewhere, but its existence as a standalone testable unit is itself part of what this task delivers. `HiveMigrationService.migrateIfNeeded(uid)` — Task 5 does not consume this further, it's called once from the new sign-in screen.

- [ ] **Step 1: Write the failing test for the migration service**

```dart
// test/core/services/hive_migration_service_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lexi_core/core/services/hive_migration_service.dart';

void main() {
  late Directory tempDir;
  late Box<String> vocabBox;
  late Box<String> topicsBox;
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_migration_test');
    Hive.init(tempDir.path);
    vocabBox = await Hive.openBox<String>('vocab_migration_${DateTime.now().millisecondsSinceEpoch}');
    topicsBox = await Hive.openBox<String>('topics_migration_${DateTime.now().millisecondsSinceEpoch}');
    firestore = FakeFirebaseFirestore();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('pushes existing Hive vocab and topics into Firestore when Hive has data', () async {
    await vocabBox.put('v1', jsonEncode({'id': 'v1', 'headword': 'apple'}));
    await topicsBox.put('t1', jsonEncode({'id': 't1', 'name': 'Travel'}));

    final service = HiveMigrationService(
      vocabBox: vocabBox,
      topicsBox: topicsBox,
      firestore: firestore,
    );
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isTrue);
    final vocabDoc = await firestore.collection('users/u1/vocab_records').doc('v1').get();
    expect(vocabDoc.data()!['headword'], 'apple');
    final topicDoc = await firestore.collection('users/u1/topics').doc('t1').get();
    expect(topicDoc.data()!['name'], 'Travel');
  });

  test('does nothing and returns false when both Hive boxes are empty', () async {
    final service = HiveMigrationService(
      vocabBox: vocabBox,
      topicsBox: topicsBox,
      firestore: firestore,
    );
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isFalse);
    final vocabSnapshot = await firestore.collection('users/u1/vocab_records').get();
    expect(vocabSnapshot.docs, isEmpty);
  });

  test('migrates even if only one of the two boxes has data', () async {
    await vocabBox.put('v1', jsonEncode({'id': 'v1', 'headword': 'apple'}));
    final service = HiveMigrationService(
      vocabBox: vocabBox,
      topicsBox: topicsBox,
      firestore: firestore,
    );
    final migrated = await service.migrateIfNeeded('u1');
    expect(migrated, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/hive_migration_service_test.dart`
Expected: FAIL — `HiveMigrationService` doesn't exist yet (compile error).

- [ ] **Step 3: Implement `HiveMigrationService`**

```dart
// lib/core/services/hive_migration_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

/// One-time push of any pre-existing local Hive vocab/topics data into a
/// newly-authenticated user's Firestore collections. Only relevant for a
/// user who used the app before sign-in became mandatory and never signed
/// in (so their data lived only in Hive, never reached Firestore via the
/// old SyncService). A user who already signed in at least once already
/// has this data on Firestore via that prior sync — this is a safety net,
/// not the primary data path going forward.
class HiveMigrationService {
  HiveMigrationService({
    required this.vocabBox,
    required this.topicsBox,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final Box<String> vocabBox;
  final Box<String> topicsBox;
  final FirebaseFirestore _firestore;

  /// Returns true if a migration actually happened (either box had data).
  Future<bool> migrateIfNeeded(String uid) async {
    if (vocabBox.isEmpty && topicsBox.isEmpty) return false;

    final vocabCol = _firestore.collection('users').doc(uid).collection('vocab_records');
    final topicsCol = _firestore.collection('users').doc(uid).collection('topics');

    var batch = _firestore.batch();
    var count = 0;

    for (final raw in vocabBox.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      batch.set(vocabCol.doc(map['id'] as String), map);
      count++;
      if (count == 500) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    for (final raw in topicsBox.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      batch.set(topicsCol.doc(map['id'] as String), map);
      count++;
      if (count == 500) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    if (count > 0) await batch.commit();

    await vocabBox.clear();
    await topicsBox.clear();
    return true;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/hive_migration_service_test.dart`
Expected: PASS, 3/3.

- [ ] **Step 5: Create the sign-in screen**

```dart
// lib/features/settings/presentation/screens/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../../core/services/hive_migration_service.dart';
import '../providers/auth_notifier.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      final user = ref.read(authNotifierProvider).valueOrNull;
      if (user != null) {
        final migration = HiveMigrationService(
          vocabBox: Hive.box<String>('vocab_records'),
          topicsBox: Hive.box<String>('topics'),
        );
        await migration.migrateIfNeeded(user.uid);
      }
      // On success, the router's redirect (driven by authNotifierProvider's
      // stream) automatically navigates away from this screen — no
      // explicit navigation call needed here.
    } catch (e) {
      if (mounted) setState(() => _error = 'Đăng nhập thất bại. Thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LexiCore',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Đăng nhập để tiếp tục'),
              const SizedBox(height: 24),
              if (_loading)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập với Google'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write the failing test for the redirect decision function**

The redirect decision (given the current location, whether Firebase's auth stream has emitted yet, and whether a user is signed in, decide where to send the user) is a pure function of those 3 inputs — pulled out of the `GoRouter` config specifically so it's unit-testable without spinning up a full widget tree or faking `FirebaseAuth`.

```dart
// test/core/router/auth_redirect_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/router/app_router.dart';

void main() {
  group('authRedirectDecision', () {
    test('before the auth stream resolves, stays on /splash', () {
      expect(
        authRedirectDecision(matchedLocation: '/splash', hasResolved: false, signedIn: false),
        isNull,
      );
    });

    test('before the auth stream resolves, redirects any other location to /splash', () {
      expect(
        authRedirectDecision(matchedLocation: '/vocab', hasResolved: false, signedIn: false),
        '/splash',
      );
    });

    test('resolved + signed out + already on /sign-in stays put', () {
      expect(
        authRedirectDecision(matchedLocation: '/sign-in', hasResolved: true, signedIn: false),
        isNull,
      );
    });

    test('resolved + signed out + anywhere else redirects to /sign-in', () {
      expect(
        authRedirectDecision(matchedLocation: '/vocab', hasResolved: true, signedIn: false),
        '/sign-in',
      );
    });

    test('resolved + signed in + on /splash redirects home', () {
      expect(
        authRedirectDecision(matchedLocation: '/splash', hasResolved: true, signedIn: true),
        '/',
      );
    });

    test('resolved + signed in + on /sign-in redirects home', () {
      expect(
        authRedirectDecision(matchedLocation: '/sign-in', hasResolved: true, signedIn: true),
        '/',
      );
    });

    test('resolved + signed in + anywhere else stays put (no redirect loop)', () {
      expect(
        authRedirectDecision(matchedLocation: '/vocab', hasResolved: true, signedIn: true),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 7: Run test to verify it fails**

Run: `flutter test test/core/router/auth_redirect_test.dart`
Expected: FAIL — `authRedirectDecision` doesn't exist yet (compile error).

- [ ] **Step 8: Add the mandatory sign-in redirect to the router**

Read `lib/core/router/app_router.dart` in full first, to see its exact current top and bottom (the `final appRouter = GoRouter(...)` declaration and its closing `);`).

Add these imports near the top of the file, alongside the existing ones:
```dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../features/settings/presentation/screens/sign_in_screen.dart';
```

Add this pure decision function and the stream-bridging helper class right before the `final appRouter = GoRouter(...)` declaration:
```dart
/// Pure redirect decision, extracted so it's unit-testable without a full
/// widget tree or a faked FirebaseAuth — see test/core/router/auth_redirect_test.dart.
/// Returns the path to redirect to, or null to stay on [matchedLocation].
String? authRedirectDecision({
  required String matchedLocation,
  required bool hasResolved,
  required bool signedIn,
}) {
  if (!hasResolved) {
    return matchedLocation == '/splash' ? null : '/splash';
  }
  if (!signedIn) {
    return matchedLocation == '/sign-in' ? null : '/sign-in';
  }
  if (matchedLocation == '/splash' || matchedLocation == '/sign-in') return '/';
  return null;
}

/// Bridges Firebase's async auth-state stream into something GoRouter's
/// `refreshListenable` can react to, and tracks whether the stream has
/// emitted at least once — until it has, [authRedirectDecision] can't yet
/// tell whether the user is signed in, so it must not redirect prematurely
/// (which would otherwise flash the sign-in screen for an already-
/// authenticated user whose session Firebase hasn't finished restoring yet).
class _AuthRefreshStream extends ChangeNotifier {
  _AuthRefreshStream() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      hasResolved = true;
      notifyListeners();
    });
  }

  bool hasResolved = false;
  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authRefreshStream = _AuthRefreshStream();
```

Change `final appRouter = GoRouter(` to add `refreshListenable` and `redirect` (delegating straight to `authRedirectDecision`), and add the `/splash` and `/sign-in` routes as top-level siblings of the existing `ShellRoute` (inside the same `routes: [...]` list, before or after `ShellRoute(...)` — add them before it):

```dart
final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: _authRefreshStream,
  redirect: (context, state) => authRedirectDecision(
    matchedLocation: state.matchedLocation,
    hasResolved: _authRefreshStream.hasResolved,
    signedIn: FirebaseAuth.instance.currentUser != null,
  ),
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        // ...every existing route under here is unchanged...
```

(Leave the entire existing `ShellRoute` subtree exactly as it is — only the new `redirect`/`refreshListenable` params on `GoRouter(...)` and the two new sibling `GoRoute`s are additions.)

- [ ] **Step 9: Run the redirect test to verify it passes**

Run: `flutter test test/core/router/auth_redirect_test.dart`
Expected: PASS, 7/7.

- [ ] **Step 10: Manual end-to-end verification (the pure decision function is unit-tested; this step checks it's actually wired up correctly in the real app, which an automated test can't easily cover here)**

Run: `flutter run` (on any available device/emulator), and manually confirm:
1. Cold start while signed out → briefly shows `/splash`, then lands on `/sign-in` (not a flash of any other screen).
2. Tapping "Đăng nhập với Google" and completing sign-in → automatically navigates to `/` (LookupScreen) with no manual back-navigation needed.
3. Signing out from Settings → automatically redirected back to `/sign-in`.

- [ ] **Step 11: Run `flutter analyze` and the full test suite**

Run: `flutter analyze`
Expected: clean.

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 12: Commit**

```bash
git add lib/core/router/app_router.dart lib/features/settings/presentation/screens/sign_in_screen.dart lib/core/services/hive_migration_service.dart test/core/services/hive_migration_service_test.dart test/core/router/auth_redirect_test.dart
git commit -m "feat: mandatory sign-in gate + one-time Hive-to-Firestore migration"
```

---

## Task 5: Delete Hive/SyncService, clean up Settings, remove Hive init

**Files:**
- Delete: `lib/core/services/sync_service.dart`
- Delete: `test/core/services/sync_service_test.dart`
- Delete: `lib/features/settings/presentation/providers/sync_notifier.dart`
- Delete: `lib/features/settings/presentation/providers/sync_notifier.g.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Modify: `lib/main.dart`
- Modify: `lib/core/di/app_providers.dart` (the `vocabRepositoryProvider` itself, now that mandatory sign-in guarantees a `uid`)
- Modify: `pubspec.yaml` (remove `hive`/`hive_flutter` from `dependencies` — check nothing else in the repo still imports them first)

**Interfaces:**
- Consumes: everything from Tasks 1-4.
- Produces: nothing — this is the final cleanup task.

- [ ] **Step 1: Confirm nothing else references Hive before deleting**

Run: `grep -rn "package:hive\|Hive\." lib/ --include="*.dart"`
Expected output: only 3 remaining files — `lib/core/di/app_providers.dart` (the `vocabRepositoryProvider`, updated in Step 4 below), `lib/features/settings/presentation/screens/sign_in_screen.dart` (Task 4's migration call, intentionally still using Hive to read the boxes being migrated away from), and `lib/main.dart` (removed in Step 5 below). If anything else appears, stop and investigate before proceeding — it means an earlier task missed a call site.

- [ ] **Step 2: Delete `SyncService` and its test**

```bash
git rm lib/core/services/sync_service.dart test/core/services/sync_service_test.dart
```

- [ ] **Step 3: Delete `SyncNotifier` and its generated file**

```bash
git rm lib/features/settings/presentation/providers/sync_notifier.dart lib/features/settings/presentation/providers/sync_notifier.g.dart
```

- [ ] **Step 4: Update `vocabRepositoryProvider` to construct against the signed-in user**

Read `lib/core/di/app_providers.dart` in full first to find the current `vocabRepositoryProvider` definition (it currently constructs `VocabRepositoryImpl()` with no arguments, or however it's currently wired — check the exact current code before editing). Replace it with:

```dart
@riverpod
VocabRepository vocabRepository(VocabRepositoryRef ref) {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) {
    throw StateError(
      'vocabRepositoryProvider read before sign-in — the router\'s mandatory '
      'sign-in redirect should make this unreachable.',
    );
  }
  return VocabRepositoryImpl(uid: user.uid);
}
```

Add the import for `authNotifierProvider` if not already present in this file:
```dart
import '../../features/settings/presentation/providers/auth_notifier.dart';
```

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `app_providers.g.dart` cleanly.

- [ ] **Step 5: Remove Hive initialization from `main.dart`**

In `lib/main.dart`, remove the import `import 'package:hive_flutter/hive_flutter.dart';` and these three lines:
```dart
  await Hive.initFlutter();
  await Hive.openBox<String>('vocab_records');
  await Hive.openBox<String>('topics');
```

- [ ] **Step 6: Clean up `settings_screen.dart`**

Read `lib/features/settings/presentation/screens/settings_screen.dart` in full first. Remove:
- The imports `import '../../../../core/services/sync_service.dart';` and `import '../providers/sync_notifier.dart';`.
- The line `final syncStatus = ref.watch(syncNotifierProvider);`.
- The `authAsync.when(...)` branching on `user == null` — since sign-in is now mandatory, `user` is always non-null by the time this screen renders. Replace:
```dart
          authAsync.when(
            data: (user) => user == null
                ? _SignedOutCard(
                    onSignIn: () async {
                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Đăng nhập thất bại. Thử lại.')),
                          );
                        }
                      }
                    },
                  )
                : _SignedInSection(
                    user: user,
                    syncStatus: syncStatus,
                    onSignOut: () =>
                        ref.read(authNotifierProvider.notifier).signOut(),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) =>
                const ListTile(title: Text('Lỗi xác thực')),
          ),
```
with:
```dart
          authAsync.when(
            data: (user) => _SignedInSection(
              user: user!,
              onSignOut: () =>
                  ref.read(authNotifierProvider.notifier).signOut(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) =>
                const ListTile(title: Text('Lỗi xác thực')),
          ),
```
- Delete the entire `_SignedOutCard` class.
- In `_SignedInSection`, remove the `syncStatus` field/constructor param and the second `ListTile` (the "Đồng bộ"/sync-status one) — keep only the first `ListTile` (avatar/name/email + "Đăng xuất" button):
```dart
class _SignedInSection extends StatelessWidget {
  const _SignedInSection({
    required this.user,
    required this.onSignOut,
  });
  final User user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.photoURL != null
            ? NetworkImage(user.photoURL!)
            : null,
        child: user.photoURL == null
            ? Text(
                (user.displayName?.isNotEmpty ?? false)
                    ? user.displayName![0].toUpperCase()
                    : '?',
              )
            : null,
      ),
      title: Text(user.displayName ?? 'Người dùng'),
      subtitle: Text(user.email ?? ''),
      trailing: TextButton(
        onPressed: onSignOut,
        child: const Text('Đăng xuất'),
      ),
    );
  }
}
```

- [ ] **Step 7: Remove `hive`/`hive_flutter` from `pubspec.yaml`**

Run: `grep -rn "package:hive" lib/ test/ --include="*.dart"` — expected: no matches remain anywhere (Task 4's `sign_in_screen.dart` and `hive_migration_service.dart`/its test are the LAST legitimate Hive usages, and they stay — this grep should only find matches in those specific files, confirming everything else is clean; if it finds nothing at all, `hive`/`hive_flutter` are still needed for the migration path, so do NOT remove them from `pubspec.yaml` — they remain dependencies as long as `HiveMigrationService`/`sign_in_screen.dart` exist, which is permanently, since a real user could still update from an old Hive-only version at any point in the future).

Given this, **do not remove `hive`/`hive_flutter` from `pubspec.yaml`** — leave this step as a no-op confirmation only, not a removal. (Correcting the task's own file list above: `pubspec.yaml` needs no edit in this task.)

- [ ] **Step 8: Run `flutter analyze` and the full test suite**

Run: `flutter analyze`
Expected: clean, no errors, no unused-import warnings.

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: delete SyncService/SyncNotifier, wire vocabRepositoryProvider to signed-in uid, clean up Settings"
```
