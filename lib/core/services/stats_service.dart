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

    // Prune entries older than 6 days ago
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final cutoffKey = _dateKey(DateTime(cutoff.year, cutoff.month, cutoff.day));
    log.removeWhere((k, _) => k.compareTo(cutoffKey) < 0);

    await prefs.setString('weekly_review_log', jsonEncode(log));
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
