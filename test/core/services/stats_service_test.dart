import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<void> save(VocabRecord record) async {}
  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async =>
      null;
  @override
  Future<void> update(VocabRecord record) async {}
  @override
  Future<void> delete(String id, {required Language language}) async {}
  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;
  @override
  Future<VocabRecord?> getByHeadword(
          String headword, Language language) async =>
      null;
  @override
  Future<List<Topic>> getTopics() async => [];
  @override
  Future<void> addTopic(Topic topic) async {}
  @override
  Future<void> deleteTopic(String id) async {}
}

VocabRecord _record(String id,
        {int sm2Interval = 1,
        DateTime? nextReviewAt,
        CEFRLevel cefr = CEFRLevel.b1}) =>
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

const _uid = 'u1';

Future<StatsService> _service({
  List<VocabRecord> records = const [],
  FakeFirebaseFirestore? firestore,
  String? uid = _uid,
}) async {
  final prefs = await SharedPreferences.getInstance();
  return StatsService(
    repository: _FakeVocabRepository(records),
    prefs: prefs,
    firestore: firestore ?? FakeFirebaseFirestore(),
    currentUid: () => uid,
  );
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('computeStats() returns zeros when there are no records', () async {
    final stats = await (await _service()).computeStats(Language.english);
    expect(stats.dueCount, 0);
    expect(stats.masteredCount, 0);
    expect(stats.totalCount, 0);
    expect(stats.currentStreak, 0);
    expect(stats.weeklyLog, isEmpty);
  });

  test('computeStats() counts due and mastered words', () async {
    final records = [
      _record('1', nextReviewAt: null),
      _record('2',
          nextReviewAt: DateTime.now().subtract(const Duration(days: 1))),
      _record('3', nextReviewAt: DateTime.now().add(const Duration(days: 5))),
      _record('4',
          sm2Interval: 25,
          nextReviewAt: DateTime.now().add(const Duration(days: 10))),
      _record('5',
          sm2Interval: 3,
          nextReviewAt: DateTime.now().add(const Duration(days: 10))),
    ];
    final stats =
        await (await _service(records: records)).computeStats(Language.english);
    expect(stats.dueCount, 2);
    expect(stats.masteredCount, 1);
    expect(stats.totalCount, 5);
  });

  test('computeStats() builds a CEFR breakdown across all 6 levels', () async {
    final records = [
      _record('1', cefr: CEFRLevel.a1),
      _record('2', cefr: CEFRLevel.a1),
      _record('3', cefr: CEFRLevel.c2),
    ];
    final stats =
        await (await _service(records: records)).computeStats(Language.english);
    expect(stats.cefrBreakdown[CEFRLevel.a1], 2);
    expect(stats.cefrBreakdown[CEFRLevel.c2], 1);
    expect(stats.cefrBreakdown[CEFRLevel.b1], 0);
  });

  test(
      'recordPracticeSession() same-day repeat accumulates the log, keeps streak',
      () async {
    final service = await _service();
    await service.recordPracticeSession(5);
    await service.recordPracticeSession(3);
    final stats = await service.computeStats(Language.english);
    expect(stats.currentStreak, 1);
    expect(stats.weeklyLog[_key(DateTime.now())], 8);
  });

  test('recordPracticeSession() writes to the shared Firestore doc web reads',
      () async {
    final fs = FakeFirebaseFirestore();
    await (await _service(firestore: fs)).recordPracticeSession(4);
    final snap = await fs
        .collection('users')
        .doc(_uid)
        .collection('stats')
        .doc('activity')
        .get();
    expect(snap.data()!['currentStreak'], 1);
    expect(snap.data()!['lastPracticedDate'], _key(DateTime.now()));
    expect((snap.data()!['weeklyLog'] as Map)[_key(DateTime.now())], 4);
  });

  test('reads a streak the web app already wrote', () async {
    final fs = FakeFirebaseFirestore();
    await fs
        .collection('users')
        .doc(_uid)
        .collection('stats')
        .doc('activity')
        .set({
      'currentStreak': 5,
      'lastPracticedDate': '2026-01-01',
      'weeklyLog': {}
    });
    final stats =
        await (await _service(firestore: fs)).computeStats(Language.english);
    expect(stats.currentStreak, 5);
  });

  test('migrates the old SharedPreferences store into Firestore once',
      () async {
    SharedPreferences.setMockInitialValues({
      'current_streak': 3,
      'last_practiced_date': _key(DateTime.now()),
      'weekly_review_log': '{"${_key(DateTime.now())}": 7}',
    });
    final fs = FakeFirebaseFirestore();
    // Firestore already has a smaller/older record.
    await fs
        .collection('users')
        .doc(_uid)
        .collection('stats')
        .doc('activity')
        .set({
      'currentStreak': 1,
      'lastPracticedDate': '2020-01-01',
      'weeklyLog': {}
    });

    final stats =
        await (await _service(firestore: fs)).computeStats(Language.english);
    expect(stats.currentStreak, 3); // max(1, 3)
    expect(stats.weeklyLog[_key(DateTime.now())], 7); // max(0, 7)

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('stats_migrated_to_firestore_v1'), isTrue);
  });

  test('no uid → recordPracticeSession is a no-op, computeStats streak is 0',
      () async {
    final service = await _service(uid: null);
    await service.recordPracticeSession(5);
    final stats = await service.computeStats(Language.english);
    expect(stats.currentStreak, 0);
  });
}
