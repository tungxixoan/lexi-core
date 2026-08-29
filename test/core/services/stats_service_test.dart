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
  Future<VocabRecord?> getById(String id, {required Language language}) async => null;
  @override
  Future<void> update(VocabRecord record) async {}
  @override
  Future<void> delete(String id, {required Language language}) async {}
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
    final stats = await service.computeStats(Language.english);
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
      _record('4', sm2Interval: 25, nextReviewAt: DateTime.now().add(const Duration(days: 10))), // mastered, not due
      _record('5', sm2Interval: 3, nextReviewAt: DateTime.now().add(const Duration(days: 10))), // not mastered, not due
    ];
    final service = StatsService(repository: _FakeVocabRepository(records), prefs: prefs);
    final stats = await service.computeStats(Language.english);
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
    final stats = await service.computeStats(Language.english);
    expect(stats.cefrBreakdown[CEFRLevel.a1], 2);
    expect(stats.cefrBreakdown[CEFRLevel.c2], 1);
    expect(stats.cefrBreakdown[CEFRLevel.b1], 0);
  });

  test('recordPracticeSession() same-day repeat call does not bump streak but accumulates the log', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StatsService(repository: _FakeVocabRepository([]), prefs: prefs);
    await service.recordPracticeSession(5);
    await service.recordPracticeSession(3);
    final stats = await service.computeStats(Language.english);
    expect(stats.currentStreak, 1);
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    expect(stats.weeklyLog[todayKey], 8);
  });
}
