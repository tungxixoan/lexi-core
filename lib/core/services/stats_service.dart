import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/dictionary/domain/entities/language.dart';
import '../../features/practice/domain/entities/learning_stats.dart';
import '../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../features/vocabulary/domain/repositories/vocab_repository.dart';

/// Daily-activity (streak + rolling 7-day review log) lives in the SAME
/// Firestore document the React web app uses — `users/{uid}/stats/activity`
/// with fields `currentStreak` / `lastPracticedDate` / `weeklyLog` — so the two
/// clients share one streak. The old SharedPreferences store is migrated in on
/// first use and then ignored.
class StatsService {
  StatsService({
    required this.repository,
    required this.prefs,
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final VocabRepository repository;
  final SharedPreferences prefs;
  final FirebaseFirestore _firestore;
  final String? Function() _currentUid;

  static const _migratedFlag = 'stats_migrated_to_firestore_v1';

  DocumentReference<Map<String, dynamic>> _activityDoc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('stats')
      .doc('activity');

  Future<LearningStats> computeStats(Language language) async {
    final now = DateTime.now();
    final records = await repository.getAll(language: language);

    int dueCount = 0;
    int masteredCount = 0;
    final cefrBreakdown = {for (final l in CEFRLevel.values) l: 0};

    for (final r in records) {
      if (r.nextReviewAt == null || r.nextReviewAt!.isBefore(now)) dueCount++;
      if (r.sm2Interval >= 21) masteredCount++;
      cefrBreakdown[r.cefrLevel] = (cefrBreakdown[r.cefrLevel] ?? 0) + 1;
    }

    final activity = await _readActivity();

    return LearningStats(
      dueCount: dueCount,
      masteredCount: masteredCount,
      totalCount: records.length,
      cefrBreakdown: cefrBreakdown,
      currentStreak: activity.streak,
      weeklyLog: activity.weeklyLog,
    );
  }

  Future<void> recordPracticeSession(int wordCount, {DateTime? now}) async {
    final uid = _currentUid();
    if (uid == null) return;
    await _migrateFromPrefsIfNeeded(uid);

    final at = now ?? DateTime.now();
    final today = _dateKey(at);
    final yesterday = _dateKey(at.subtract(const Duration(days: 1)));

    final current = await _readActivity();

    final int newStreak;
    if (current.lastPracticedDate == today) {
      newStreak = current.streak;
    } else if (current.lastPracticedDate == yesterday) {
      newStreak = current.streak + 1;
    } else {
      newStreak = 1;
    }

    final log = {...current.weeklyLog};
    log[today] = (log[today] ?? 0) + wordCount;
    _pruneToRollingWeek(log, at);

    await _activityDoc(uid).set({
      'currentStreak': newStreak,
      'lastPracticedDate': today,
      'weeklyLog': log,
    }, SetOptions(merge: true));
  }

  Future<_Activity> _readActivity() async {
    final uid = _currentUid();
    if (uid == null) return const _Activity(0, null, {});
    await _migrateFromPrefsIfNeeded(uid);
    try {
      final snap = await _activityDoc(uid).get();
      final data = snap.data() ?? const {};
      return _Activity(
        (data['currentStreak'] as num?)?.toInt() ?? 0,
        data['lastPracticedDate'] as String?,
        _decodeLog(data['weeklyLog']),
      );
    } catch (_) {
      return const _Activity(0, null, {});
    }
  }

  /// Fold whatever the old on-device SharedPreferences store holds into the
  /// Firestore doc, once — max streak, latest date, max per day — then leave
  /// the prefs alone forever.
  Future<void> _migrateFromPrefsIfNeeded(String uid) async {
    if (prefs.getBool(_migratedFlag) ?? false) return;

    final spStreak = prefs.getInt('current_streak');
    final spLast = prefs.getString('last_practiced_date');
    final spLogJson = prefs.getString('weekly_review_log');

    if (spStreak == null && spLast == null && spLogJson == null) {
      await prefs.setBool(_migratedFlag, true);
      return;
    }

    final spLog = spLogJson == null ? <String, int>{} : _decodeLog(spLogJson);

    try {
      final snap = await _activityDoc(uid).get();
      final data = snap.data() ?? const {};
      final fsStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
      final fsLast = data['lastPracticedDate'] as String?;
      final fsLog = _decodeLog(data['weeklyLog']);

      final mergedLog = {...fsLog};
      spLog.forEach((k, v) => mergedLog[k] = math.max(mergedLog[k] ?? 0, v));
      _pruneToRollingWeek(mergedLog, DateTime.now());

      await _activityDoc(uid).set({
        'currentStreak': math.max(fsStreak, spStreak ?? 0),
        'lastPracticedDate': _laterKey(fsLast, spLast),
        'weeklyLog': mergedLog,
      }, SetOptions(merge: true));
      await prefs.setBool(_migratedFlag, true);
    } catch (_) {
      // Offline / permission error — try again next time.
    }
  }

  Map<String, int> _decodeLog(Object? raw) {
    if (raw is String) {
      raw = jsonDecode(raw);
    }
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    return {};
  }

  void _pruneToRollingWeek(Map<String, int> log, DateTime now) {
    final cutoff = now.subtract(const Duration(days: 6));
    final cutoffKey = _dateKey(DateTime(cutoff.year, cutoff.month, cutoff.day));
    log.removeWhere((k, _) => k.compareTo(cutoffKey) < 0);
  }

  String? _laterKey(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) >= 0 ? a : b;
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _Activity {
  const _Activity(this.streak, this.lastPracticedDate, this.weeklyLog);
  final int streak;
  final String? lastPracticedDate;
  final Map<String, int> weeklyLog;
}
