# Plan 5 — Task 04: LearningStats Entity + StatsService + UseCase + DI

**Context:** Task 04 of Plan 5. Tasks 01–03 must be complete. See `plan5-global-constraints.md` for project-wide rules.

**Files:**
- Create: `lib/features/practice/domain/entities/learning_stats.dart`
- Create: `lib/core/services/stats_service.dart`
- Create: `lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart`
- Modify: `lib/core/di/app_providers.dart`
- Create: `test/core/services/stats_service_test.dart`

**Interfaces:**
- Consumes: `VocabRecord.fromJson()`, `CEFRLevel` enum (`a1,a2,b1,b2,c1,c2`), `SharedPreferences`
- Produces:
  - `LearningStats` — fields: `dueCount: int`, `masteredCount: int`, `totalCount: int`, `cefrBreakdown: Map<CEFRLevel, int>`, `currentStreak: int`, `weeklyLog: Map<String, int>`
  - `StatsService(vocabBox: Box<String>, prefs: SharedPreferences)`
    - `.computeStats() → LearningStats` (synchronous)
    - `.recordPracticeSession(int wordCount) → Future<void>`
  - `statsServiceProvider` — auto-dispose Riverpod provider
  - `getLearningStatsUseCaseProvider` — auto-dispose Riverpod provider
  - `learningStatsProvider` — auto-dispose Riverpod provider (used by ProgressScreen in Task 05)

**Domain rules:**
- Mastered: `sm2Interval >= 21`
- Due: `nextReviewAt == null || nextReviewAt!.isBefore(DateTime.now())`
- Streak increments if last practiced was yesterday; resets to 1 if gap > 1 day; stays same if last practiced was today
- Weekly log prunes entries older than 6 days ago

---

- [ ] **Step 1: Write failing tests**

Create `test/core/services/stats_service_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```
flutter test test/core/services/stats_service_test.dart
```

Expected: FAIL (StatsService not found).

- [ ] **Step 3: Create LearningStats entity**

Create `lib/features/practice/domain/entities/learning_stats.dart`:

```dart
import '../../../vocabulary/domain/entities/cefr_level.dart';

final class LearningStats {
  const LearningStats({
    required this.dueCount,
    required this.masteredCount,
    required this.totalCount,
    required this.cefrBreakdown,
    required this.currentStreak,
    required this.weeklyLog,
  });

  final int dueCount;
  final int masteredCount;
  final int totalCount;
  final Map<CEFRLevel, int> cefrBreakdown;
  final int currentStreak;
  final Map<String, int> weeklyLog; // "yyyy-MM-dd" → words practiced
}
```

- [ ] **Step 4: Create StatsService**

Create `lib/core/services/stats_service.dart`:

```dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/practice/domain/entities/learning_stats.dart';
import '../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../features/vocabulary/domain/entities/vocab_record.dart';

class StatsService {
  StatsService({required this.vocabBox, required this.prefs});

  final Box<String> vocabBox;
  final SharedPreferences prefs;

  LearningStats computeStats() {
    final now = DateTime.now();
    final records = vocabBox.values
        .map((s) => VocabRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();

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
```

- [ ] **Step 5: Create GetLearningStatsUseCase**

Create `lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart`:

```dart
import '../../../core/services/stats_service.dart';
import '../entities/learning_stats.dart';

class GetLearningStatsUseCase {
  const GetLearningStatsUseCase(this._statsService);
  final StatsService _statsService;

  LearningStats execute() => _statsService.computeStats();
}
```

- [ ] **Step 6: Add providers to app_providers.dart**

In `lib/core/di/app_providers.dart`, add these imports (after the existing practice imports):

```dart
import 'package:hive/hive.dart';
import '../../core/services/stats_service.dart';
import '../../features/practice/domain/entities/learning_stats.dart';
import '../../features/practice/domain/use_cases/get_learning_stats_use_case.dart';
```

Add these 3 providers at the bottom of the file (before the closing, if any):

```dart
@riverpod
StatsService statsService(StatsServiceRef ref) => StatsService(
      vocabBox: Hive.box<String>('vocab_records'),
      prefs: ref.read(sharedPreferencesProvider),
    );

@riverpod
GetLearningStatsUseCase getLearningStatsUseCase(
        GetLearningStatsUseCaseRef ref) =>
    GetLearningStatsUseCase(ref.read(statsServiceProvider));

@riverpod
LearningStats learningStats(LearningStatsRef ref) =>
    ref.read(statsServiceProvider).computeStats();
```

- [ ] **Step 7: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `app_providers.g.dart` regenerated with `statsServiceProvider`, `getLearningStatsUseCaseProvider`, `learningStatsProvider`.

- [ ] **Step 8: Run tests — now pass**

```
flutter test test/core/services/stats_service_test.dart
```

Expected: 4/4 pass.

- [ ] **Step 9: Run full suite**

```
flutter test
```

Expected: all tests pass.

- [ ] **Step 10: Commit**

```
git add lib/features/practice/domain/entities/learning_stats.dart \
        lib/core/services/stats_service.dart \
        lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart \
        lib/core/di/app_providers.dart \
        lib/core/di/app_providers.g.dart \
        test/core/services/stats_service_test.dart
git commit -m "feat(plan5): add LearningStats entity, StatsService, GetLearningStatsUseCase, DI providers"
```

**Report status:** DONE
