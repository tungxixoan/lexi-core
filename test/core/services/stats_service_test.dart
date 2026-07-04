import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';

void main() {
  late Box<String> vocabBox;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stats_test');
    Hive.init(tempDir.path);
    vocabBox = await Hive.openBox<String>(
        'vocab_stats_${DateTime.now().millisecondsSinceEpoch}');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('computeStats() returns zeros when vocab box is empty', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StatsService(vocabBox: vocabBox, prefs: prefs);
    final stats = service.computeStats();
    expect(stats.dueCount, 0);
    expect(stats.masteredCount, 0);
    expect(stats.totalCount, 0);
    expect(stats.currentStreak, 0);
    expect(stats.weeklyLog, isEmpty);
  });

  test('computeStats() correctly counts due and mastered words', () async {
    final prefs = await SharedPreferences.getInstance();
    // Due: nextReviewAt == null
    await vocabBox.put('id1', jsonEncode(_record('id1', sm2Interval: 5)));
    // Due: nextReviewAt in the past
    await vocabBox.put(
        'id2',
        jsonEncode(_record('id2',
            sm2Interval: 3,
            nextReviewAt: DateTime.now().subtract(const Duration(hours: 1)))));
    // Not due, but mastered (sm2Interval >= 21)
    await vocabBox.put(
        'id3',
        jsonEncode(_record('id3',
            sm2Interval: 21,
            nextReviewAt: DateTime.now().add(const Duration(days: 10)))));
    // Not due, not mastered
    await vocabBox.put(
        'id4',
        jsonEncode(_record('id4',
            sm2Interval: 7,
            nextReviewAt: DateTime.now().add(const Duration(days: 3)))));

    final service = StatsService(vocabBox: vocabBox, prefs: prefs);
    final stats = service.computeStats();
    expect(stats.dueCount, 2);
    expect(stats.masteredCount, 1);
    expect(stats.totalCount, 4);
  });

  test('computeStats() builds correct CEFR breakdown', () async {
    final prefs = await SharedPreferences.getInstance();
    await vocabBox.put('id1', jsonEncode(_record('id1', cefr: 'a1')));
    await vocabBox.put('id2', jsonEncode(_record('id2', cefr: 'a1')));
    await vocabBox.put('id3', jsonEncode(_record('id3', cefr: 'b2')));

    final service = StatsService(vocabBox: vocabBox, prefs: prefs);
    final stats = service.computeStats();
    expect(stats.cefrBreakdown[CEFRLevel.a1], 2);
    expect(stats.cefrBreakdown[CEFRLevel.b2], 1);
    expect(stats.cefrBreakdown[CEFRLevel.c1], 0);
  });

  test('recordPracticeSession() increments streak on consecutive days and resets on gap',
      () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yKey = _dateKey(yesterday);
    SharedPreferences.setMockInitialValues({
      'last_practiced_date': yKey,
      'current_streak': 3,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = StatsService(vocabBox: vocabBox, prefs: prefs);

    await service.recordPracticeSession(5);
    expect(prefs.getInt('current_streak'), 4);

    // Simulate missing a day — last date = 2 days ago
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    SharedPreferences.setMockInitialValues({
      'last_practiced_date': _dateKey(twoDaysAgo),
      'current_streak': 5,
    });
    final prefs2 = await SharedPreferences.getInstance();
    final service2 = StatsService(vocabBox: vocabBox, prefs: prefs2);
    await service2.recordPracticeSession(3);
    expect(prefs2.getInt('current_streak'), 1);
  });
}

String _dateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _record(String id, {
  int sm2Interval = 1,
  DateTime? nextReviewAt,
  String cefr = 'b1',
}) =>
    {
      'id': id,
      'headword': 'word_$id',
      'inputType': 'word',
      'ipa': '',
      'meaning': 'meaning',
      'examples': <String>[],
      'personalNotes': '',
      'topicIds': <String>[],
      'targetLanguage': 'english',
      'cefrLevel': cefr,
      'activeContext': 'general',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'sm2Repetitions': 0,
      'sm2EaseFactor': 2.5,
      'sm2Interval': sm2Interval,
    };
