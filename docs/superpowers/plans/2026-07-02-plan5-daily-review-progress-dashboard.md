# Plan 5: Daily Review + Progress Dashboard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a ProgressScreen with SM-2 learning stats + "Ôn hôm nay" mode that filters vocab by due date + two daily local notifications (smart on first due word, fixed at user-set time) with Duolingo-style troll messages when nothing is due.

**Architecture:** `StatsService` (plain Dart class) reads Hive `vocab_records` + SharedPreferences synchronously to compute `LearningStats` and record session history. `NotificationService` wraps `flutter_local_notifications` to schedule notification ID 1 (one-time at `nextReviewAt`) and ID 2 (daily at user-set time). `NotificationNotifier` (keepAlive Riverpod) reschedules on settings change + on app resume. `ProgressScreen` at `/practice/progress` opened via 📊 icon on PracticeHomeScreen AppBar.

**Tech Stack:** Flutter 3.x + Dart 3.x, Riverpod 2.x (`@riverpod` annotation), Hive, SharedPreferences, `flutter_local_notifications ^17.0.0`, `timezone ^0.9.4`, GoRouter, mocktail.

## Global Constraints

- Flutter 3.x + Dart 3.x, iOS and Android only
- Riverpod 2.x: `@Riverpod(keepAlive: true)` for long-lived providers; `ref.read()` in async/callbacks; `ref.watch()` only in `build()`
- New packages: `flutter_local_notifications: ^17.0.0`, `timezone: ^0.9.4`
- Mastered threshold: `sm2Interval >= 21` (days)
- Due threshold: `nextReviewAt == null || nextReviewAt!.isBefore(DateTime.now())`
- Streak: increments on completing ≥1 session that calendar day; resets to 0 if a day is skipped
- Weekly log: `Map<String, int>` keyed by `"yyyy-MM-dd"`, value = total words practiced that day
- Notification ID 1 = smart (one-time), ID 2 = fixed daily repeat
- All UI copy in Vietnamese
- NEVER store `geminiApiKey` in Firestore (unchanged from Plan 4)
- No new Hive boxes; no Firebase changes

## SharedPreferences Keys Added in Plan 5

| Key | Type | Default |
|-----|------|---------|
| `reminder_enabled` | bool | false |
| `reminder_hour` | int | 20 |
| `reminder_minute` | int | 0 |
| `last_practiced_date` | String | `''` |
| `current_streak` | int | 0 |
| `weekly_review_log` | String (JSON) | `'{}'` |

---

### Task 01: Packages + Platform Config + Timezone Init

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `flutter_local_notifications` and `timezone` available to all later tasks; `tz.initializeTimeZones()` called before `runApp`

- [ ] **Step 1: Add packages to pubspec.yaml**

Add under `dependencies:` (after `google_sign_in`):
```yaml
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.4
```

- [ ] **Step 2: Run flutter pub get**

```
flutter pub get
```

Expected: resolves without conflicts.

- [ ] **Step 3: Update AndroidManifest.xml**

Add the 3 permission lines inside `<manifest>` (before `<application>`):
```xml
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Add the 2 receivers inside `<application>` (after the `<meta-data flutterEmbedding>` tag):
```xml
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
```

- [ ] **Step 4: Update main.dart — add timezone init**

Add import at top of `lib/main.dart`:
```dart
import 'package:timezone/data/latest.dart' as tz;
```

Add call as the first line inside `main()` (before `WidgetsFlutterBinding.ensureInitialized()`):
```dart
  tz.initializeTimeZones();
```

The full updated `main()`:
```dart
void main() async {
  tz.initializeTimeZones();
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(plan4-task-01): Uncomment once firebase_options.dart is generated:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox<String>('vocab_records');
  await Hive.openBox<String>('topics');
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const LexiCoreApp(),
  ));
}
```

- [ ] **Step 5: Run flutter analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 6: Run full test suite**

```
flutter test
```

Expected: all existing tests pass.

- [ ] **Step 7: Commit**

```
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/main.dart
git commit -m "chore(plan5): add flutter_local_notifications + timezone packages and platform config"
```

---

### Task 02: UserSettingsState Reminder Fields + Setters

**Files:**
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Modify: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

**Interfaces:**
- Produces:
  - `UserSettingsState.reminderEnabled: bool` (default `false`)
  - `UserSettingsState.reminderHour: int` (default `20`)
  - `UserSettingsState.reminderMinute: int` (default `0`)
  - `UserSettingsNotifier.setReminderEnabled({required bool enabled})`
  - `UserSettingsNotifier.setReminderHour(int hour)`
  - `UserSettingsNotifier.setReminderMinute(int minute)`

- [ ] **Step 1: Write failing tests**

Add to `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart` inside `main()`:

```dart
  group('reminder settings', () {
    test('reminderEnabled defaults to false', () {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      expect(container.read(userSettingsNotifierProvider).reminderEnabled, false);
    });

    test('setReminderEnabled persists to prefs and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      container.read(userSettingsNotifierProvider.notifier).setReminderEnabled(enabled: true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('reminder_enabled'), true);
      expect(container.read(userSettingsNotifierProvider).reminderEnabled, true);
    });

    test('reminderHour defaults to 20 and setReminderHour persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      expect(container.read(userSettingsNotifierProvider).reminderHour, 20);
      container.read(userSettingsNotifierProvider.notifier).setReminderHour(8);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reminder_hour'), 8);
      expect(container.read(userSettingsNotifierProvider).reminderHour, 8);
    });
  });
```

- [ ] **Step 2: Run tests to confirm they fail**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: FAIL (reminderEnabled not found on UserSettingsState).

- [ ] **Step 3: Update UserSettingsState**

Replace the full content of `lib/features/dictionary/domain/entities/user_settings_state.dart`:

```dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'app_context.dart';
import 'language.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.geminiApiKey,
    this.targetCefrLevel,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  final CEFRLevel? targetCefrLevel;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  static const _absent = Object();

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    String? geminiApiKey,
    Object? targetCefrLevel = _absent,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      UserSettingsState(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        activeContext: activeContext ?? this.activeContext,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        targetCefrLevel: identical(targetCefrLevel, _absent)
            ? this.targetCefrLevel
            : targetCefrLevel as CEFRLevel?,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );

  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    activeContext: AppContext.general,
    aiEnabled: false,
    geminiApiKey: '',
    targetCefrLevel: null,
    reminderEnabled: false,
    reminderHour: 20,
    reminderMinute: 0,
  );
}
```

- [ ] **Step 4: Update UserSettingsNotifier**

Replace the full content of `lib/features/dictionary/presentation/providers/user_settings_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

part 'user_settings_provider.g.dart';

// Overridden in main.dart with the real SharedPreferences instance.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError(
        'sharedPreferencesProvider must be overridden in main.dart');

@Riverpod(keepAlive: true)
class UserSettingsNotifier extends _$UserSettingsNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  UserSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return UserSettingsState(
      targetLanguage: Language.values.byName(
          prefs.getString('target_language') ?? Language.english.name),
      activeContext: AppContext.values.byName(
          prefs.getString('active_context') ?? AppContext.general.name),
      aiEnabled: prefs.getBool('ai_enabled') ?? false,
      geminiApiKey: prefs.getString('gemini_api_key') ?? '',
      targetCefrLevel: prefs.containsKey('target_cefr_level')
          ? CEFRLevel.values.byName(prefs.getString('target_cefr_level')!)
          : null,
      reminderEnabled: prefs.getBool('reminder_enabled') ?? false,
      reminderHour: prefs.getInt('reminder_hour') ?? 20,
      reminderMinute: prefs.getInt('reminder_minute') ?? 0,
    );
  }

  void setTargetLanguage(Language lang) {
    _prefs.setString('target_language', lang.name);
    state = state.copyWith(targetLanguage: lang);
  }

  void setActiveContext(AppContext context) {
    _prefs.setString('active_context', context.name);
    state = state.copyWith(activeContext: context);
  }

  void setAiEnabled({required bool enabled}) {
    _prefs.setBool('ai_enabled', enabled);
    state = state.copyWith(aiEnabled: enabled);
  }

  void setGeminiApiKey(String key) {
    _prefs.setString('gemini_api_key', key);
    state = state.copyWith(geminiApiKey: key);
  }

  void setTargetCefrLevel(CEFRLevel? level) {
    if (level == null) {
      _prefs.remove('target_cefr_level');
    } else {
      _prefs.setString('target_cefr_level', level.name);
    }
    state = state.copyWith(targetCefrLevel: level);
  }

  void setReminderEnabled({required bool enabled}) {
    _prefs.setBool('reminder_enabled', enabled);
    state = state.copyWith(reminderEnabled: enabled);
  }

  void setReminderHour(int hour) {
    _prefs.setInt('reminder_hour', hour);
    state = state.copyWith(reminderHour: hour);
  }

  void setReminderMinute(int minute) {
    _prefs.setInt('reminder_minute', minute);
    state = state.copyWith(reminderMinute: minute);
  }
}
```

- [ ] **Step 5: Run failing tests — now pass**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: all tests pass (existing + 3 new).

- [ ] **Step 6: Run full suite**

```
flutter test
```

Expected: all existing tests pass.

- [ ] **Step 7: Commit**

```
git add lib/features/dictionary/domain/entities/user_settings_state.dart lib/features/dictionary/presentation/providers/user_settings_provider.dart test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
git commit -m "feat(plan5): add reminderEnabled/Hour/Minute to UserSettingsState and notifier"
```

---

### Task 03: dueOnly Filter in VocabRepository + UseCase

**Files:**
- Modify: `lib/features/vocabulary/domain/repositories/vocab_repository.dart`
- Modify: `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`
- Modify: `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`
- Modify: `test/features/dictionary/presentation/providers/lookup_provider_test.mocks.dart`
- Modify: `test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart`

**Interfaces:**
- Consumes: nothing new
- Produces:
  - `VocabRepository.getAll({..., bool dueOnly = false})`
  - `GetVocabListUseCase.execute({..., bool dueOnly = false})`

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

In `lib/features/vocabulary/domain/repositories/vocab_repository.dart`, add `bool dueOnly = false` to `getAll`:

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

In `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`, add `bool dueOnly = false` to the signature and a filter block after the `maxCefrLevel` block:

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

Replace `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`:

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

- [ ] **Step 6: Patch MockVocabRepository in lookup_provider_test.mocks.dart**

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
git add lib/features/vocabulary/domain/repositories/vocab_repository.dart lib/features/vocabulary/data/repositories/vocab_repository_impl.dart lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart test/features/dictionary/presentation/providers/lookup_provider_test.mocks.dart test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
git commit -m "feat(plan5): add dueOnly filter to VocabRepository and GetVocabListUseCase"
```

---

### Task 04: LearningStats Entity + StatsService + UseCase + DI

**Files:**
- Create: `lib/features/practice/domain/entities/learning_stats.dart`
- Create: `lib/core/services/stats_service.dart`
- Create: `lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart`
- Modify: `lib/core/di/app_providers.dart`
- Create: `test/core/services/stats_service_test.dart`

**Interfaces:**
- Consumes: `VocabRecord.fromJson()`, `CEFRLevel`, `SharedPreferences`
- Produces:
  - `LearningStats` entity (dueCount, masteredCount, totalCount, cefrBreakdown, currentStreak, weeklyLog)
  - `StatsService(vocabBox, prefs).computeStats() → LearningStats`
  - `StatsService.recordPracticeSession(int wordCount) → Future<void>`
  - `statsServiceProvider` (auto-dispose)
  - `getLearningStatsUseCaseProvider` (auto-dispose)
  - `learningStatsProvider` (auto-dispose, computes stats; used by ProgressScreen)

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
    expect(stats.dueCount, 2);    // id1 + id2
    expect(stats.masteredCount, 1); // id3
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

- [ ] **Step 6: Register providers in app_providers.dart**

Add these imports to `lib/core/di/app_providers.dart`:

```dart
import 'package:hive/hive.dart';
import '../../core/services/stats_service.dart';
import '../../features/practice/domain/entities/learning_stats.dart';
import '../../features/practice/domain/use_cases/get_learning_stats_use_case.dart';
```

Add these 3 providers at the bottom of `lib/core/di/app_providers.dart`:

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
git add lib/features/practice/domain/entities/learning_stats.dart lib/core/services/stats_service.dart lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart test/core/services/stats_service_test.dart
git commit -m "feat(plan5): add LearningStats entity, StatsService, GetLearningStatsUseCase, DI providers"
```

---

### Task 05: ProgressScreen UI + Route + AppBar Icon

**Files:**
- Create: `lib/features/practice/presentation/screens/progress_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart`

**Interfaces:**
- Consumes: `learningStatsProvider` (Task 04), `getVocabListUseCaseProvider`, `SessionConfig`
- Produces: `ProgressScreen` at route `/practice/progress`

- [ ] **Step 1: Create ProgressScreen**

Create `lib/features/practice/presentation/screens/progress_screen.dart`:

```dart
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/exercise_result.dart';
import '../../domain/entities/learning_stats.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(learningStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tiến độ học')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StreakBanner(streak: stats.currentStreak),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Hôm nay',
                  value: '${stats.dueCount}',
                  icon: Icons.today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Đã thuộc',
                  value: '${stats.masteredCount}',
                  icon: Icons.military_tech_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.dueCount > 0) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startDueSession(context, ref),
                icon: const Icon(Icons.play_arrow),
                label: Text('Ôn ${stats.dueCount} từ ngay'),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('7 ngày qua', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _WeeklyChart(weeklyLog: stats.weeklyLog),
          const SizedBox(height: 24),
          Text('Theo cấp độ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _CefrBreakdown(
              breakdown: stats.cefrBreakdown, total: stats.totalCount),
        ],
      ),
    );
  }

  Future<void> _startDueSession(BuildContext context, WidgetRef ref) async {
    final words =
        await ref.read(getVocabListUseCaseProvider).execute(dueOnly: true);
    if (words.isEmpty || !context.mounted) return;
    final shuffled = List<VocabRecord>.from(words)..shuffle();
    context.push('/practice/session', extra: SessionConfig(words: shuffled));
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: streak > 0 ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              streak > 0 ? '🔥' : '❄️',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streak > 0
                        ? '$streak ngày liên tiếp'
                        : 'Chưa có streak',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    streak > 0
                        ? 'Tiếp tục giữ streak nhé!'
                        : 'Bắt đầu hôm nay nhé!',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.weeklyLog});
  final Map<String, int> weeklyLog;

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = days.map((d) => weeklyLog[_dateKey(d)] ?? 0).toList();
    final labels = List.generate(7, (i) {
      if (i == 6) return 'H';
      return ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][days[i].weekday - 1];
    });
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _WeeklyChartPainter(
            counts: counts, labels: labels, color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WeeklyChartPainter extends CustomPainter {
  _WeeklyChartPainter(
      {required this.counts, required this.labels, required this.color});
  final List<int> counts;
  final List<String> labels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = counts.isEmpty ? 0 : counts.reduce(max);
    final barWidth = size.width / counts.length;
    const minBarHeight = 4.0;
    const labelHeight = 20.0;
    final chartHeight = size.height - labelHeight;

    final barPaint = Paint()..color = color;
    final textStyle =
        TextStyle(fontSize: 10, color: Colors.grey.shade600);

    for (int i = 0; i < counts.length; i++) {
      final barHeight = maxCount == 0
          ? minBarHeight
          : (counts[i] / maxCount * (chartHeight - minBarHeight)) +
              minBarHeight;
      final x = i * barWidth;
      final y = chartHeight - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y, barWidth - 8, barHeight),
          const Radius.circular(4),
        ),
        barPaint,
      );
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(x + (barWidth - tp.width) / 2, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyChartPainter old) =>
      old.counts != counts || old.color != color;
}

class _CefrBreakdown extends StatelessWidget {
  const _CefrBreakdown(
      {required this.breakdown, required this.total});
  final Map<CEFRLevel, int> breakdown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: CEFRLevel.values.map((level) {
        final count = breakdown[level] ?? 0;
        final fraction = total == 0 ? 0.0 : count / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(level.label,
                    style: theme.textTheme.labelMedium),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(value: fraction),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text('$count',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 2: Add /practice/progress route to app_router.dart**

In `lib/core/router/app_router.dart`, add import:
```dart
import '../../features/practice/presentation/screens/progress_screen.dart';
```

Inside the `/practice` GoRoute's `routes` list, add `progress` as first child (before `session`):
```dart
GoRoute(
  path: 'progress',
  builder: (context, state) => const ProgressScreen(),
),
```

- [ ] **Step 3: Add 📊 icon to PracticeHomeScreen AppBar**

In `lib/features/practice/presentation/screens/practice_home_screen.dart`, update the `Scaffold`'s `appBar`:

```dart
appBar: AppBar(
  title: const Text('Luyện tập'),
  actions: [
    IconButton(
      icon: const Icon(Icons.bar_chart_outlined),
      tooltip: 'Tiến độ học',
      onPressed: () => context.push('/practice/progress'),
    ),
  ],
),
```

- [ ] **Step 4: Run flutter analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 5: Run full suite**

```
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```
git add lib/features/practice/presentation/screens/progress_screen.dart lib/core/router/app_router.dart lib/features/practice/presentation/screens/practice_home_screen.dart
git commit -m "feat(plan5): add ProgressScreen with stats UI, /practice/progress route, and AppBar icon"
```

---

### Task 06: NotificationService + NotificationNotifier + AppShell Observer

**Files:**
- Create: `lib/core/services/notification_service.dart`
- Create: `lib/features/practice/presentation/providers/notification_notifier.dart`
- Generated: `lib/features/practice/presentation/providers/notification_notifier.g.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Create: `test/core/services/notification_service_test.dart`

**Interfaces:**
- Consumes: `userSettingsNotifierProvider` (Task 02), `getLearningStatsUseCaseProvider` (Task 04), `flutter_local_notifications`, `timezone`
- Produces:
  - `NotificationService.initialize()`
  - `NotificationService.scheduleAll({enabled, hour, minute, dueCount, nextDueAt})`
  - `NotificationService.cancelAll()`
  - `notificationNotifierProvider` (keepAlive, void state)
  - `NotificationNotifier.reschedule() → Future<void>` — called by SessionResultScreen + AppShell

- [ ] **Step 1: Write failing tests**

Create `test/core/services/notification_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/notification_service.dart';

void main() {
  test('NotificationService can be constructed without error', () {
    final service = NotificationService();
    expect(service, isNotNull);
  });

  test('NotificationService exposes initialize and cancelAll', () {
    final service = NotificationService();
    expect(service.initialize, isA<Function>());
    expect(service.cancelAll, isA<Function>());
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```
flutter test test/core/services/notification_service_test.dart
```

Expected: FAIL (NotificationService not found).

- [ ] **Step 3: Create NotificationService**

Create `lib/core/services/notification_service.dart`:

```dart
import 'dart:developer' as dev;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'lexi_core_reminders';
  static const _channelName = 'Nhắc nhở ôn từ';
  static const _smartId = 1;
  static const _fixedId = 2;

  static const _trollTitles = [
    'Ổn lắm~ 😏',
    'Streak đang cháy 🔥',
    'Không có gì cần ôn hôm nay',
    'Bộ nhớ sẽ mờ dần... 🧠',
    'Ổn lắm~ nhưng...',
  ];

  static const _trollBodies = [
    'Bạn đã ôn xong rồi... nhưng một chút nữa thôi không? 👀',
    'Đừng để nó tắt nhé! Học thêm một chút đi~',
    'Nhưng thêm từ mới vào bank đi! 📖',
    'Học thêm một chút đi để chắc ăn hơn!',
    'Duolingo owl đang nhìn bạn đấy 🦉',
  ];

  Future<void> initialize() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  Future<void> scheduleAll({
    required bool enabled,
    required int hour,
    required int minute,
    required int dueCount,
    required DateTime? nextDueAt,
  }) async {
    if (!enabled) {
      await cancelAll();
      return;
    }

    await _plugin.cancel(_smartId);
    await _plugin.cancel(_fixedId);

    // Notification 1: one-time smart notification at nextDueAt
    if (nextDueAt != null) {
      try {
        await _plugin.zonedSchedule(
          _smartId,
          '⏰ Đến giờ ôn từ rồi!',
          'Có từ vừa đến hạn ôn. Mở app để bắt đầu 📚',
          tz.TZDateTime.from(nextDueAt, tz.local),
          _details(),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        dev.log('NotificationService: smart schedule failed: $e');
      }
    }

    // Notification 2: fixed daily at hour:minute
    final String title, body;
    if (dueCount > 0) {
      title = '📚 Ôn từ hàng ngày';
      body = 'Bạn có $dueCount từ đang chờ được ôn!';
    } else {
      final idx = DateTime.now().millisecond % 5;
      title = _trollTitles[idx];
      body = _trollBodies[idx];
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        _fixedId,
        title,
        body,
        scheduledTime,
        _details(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      dev.log('NotificationService: fixed schedule failed: $e');
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancel(_smartId);
    await _plugin.cancel(_fixedId);
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );
}
```

- [ ] **Step 4: Create NotificationNotifier**

Create `lib/features/practice/presentation/providers/notification_notifier.dart`:

```dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';

part 'notification_notifier.g.dart';

@Riverpod(keepAlive: true)
class NotificationNotifier extends _$NotificationNotifier {
  final _service = NotificationService();

  @override
  void build() {
    _service.initialize();
    ref.listen(userSettingsNotifierProvider, (_, __) => reschedule());
    Future.microtask(reschedule);
  }

  Future<void> reschedule() async {
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.reminderEnabled) {
      await _service.cancelAll();
      return;
    }
    final stats = ref.read(getLearningStatsUseCaseProvider).execute();
    final nextDueAt = _computeNextDueAt();
    await _service.scheduleAll(
      enabled: settings.reminderEnabled,
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      dueCount: stats.dueCount,
      nextDueAt: nextDueAt,
    );
  }

  DateTime? _computeNextDueAt() {
    final box = Hive.box<String>('vocab_records');
    final now = DateTime.now();
    DateTime? earliest;
    for (final raw in box.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final nextReviewRaw = map['nextReviewAt'] as String?;
      if (nextReviewRaw == null) continue;
      final dt = DateTime.parse(nextReviewRaw);
      if (dt.isAfter(now)) {
        if (earliest == null || dt.isBefore(earliest)) earliest = dt;
      }
    }
    return earliest;
  }
}
```

- [ ] **Step 5: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `notification_notifier.g.dart` generated.

- [ ] **Step 6: Update AppShell to ConsumerStatefulWidget with lifecycle observer**

Replace the full content of `lib/core/widgets/app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/practice/presentation/providers/notification_notifier.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationNotifierProvider.notifier).reschedule();
    }
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/vocab')) return 1;
    if (location.startsWith('/practice')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/vocab');
            case 2:
              context.go('/practice');
            case 3:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Vocab Bank',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Luyện tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run tests — now pass**

```
flutter test test/core/services/notification_service_test.dart
```

Expected: 2/2 pass.

- [ ] **Step 8: Run full suite and analyze**

```
flutter test
flutter analyze lib/
```

Expected: all tests pass, no errors.

- [ ] **Step 9: Commit**

```
git add lib/core/services/notification_service.dart lib/features/practice/presentation/providers/notification_notifier.dart lib/features/practice/presentation/providers/notification_notifier.g.dart lib/core/widgets/app_shell.dart test/core/services/notification_service_test.dart
git commit -m "feat(plan5): add NotificationService, NotificationNotifier, and AppShell lifecycle observer"
```

---

### Task 07: SessionResultScreen Hook + PracticeHomeScreen "Ôn hôm nay" Button

**Files:**
- Modify: `lib/features/practice/presentation/screens/session_result_screen.dart`
- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart`

**Interfaces:**
- Consumes: `statsServiceProvider` (Task 04), `notificationNotifierProvider` (Task 06)
- Produces: After each session — streak updated, weekly log updated, notifications rescheduled

- [ ] **Step 1: Update SessionResultScreen — hook stats + notifications after SM-2**

In `lib/features/practice/presentation/screens/session_result_screen.dart`:

Add imports:
```dart
import '../providers/notification_notifier.dart';
```

The `statsServiceProvider` is already available via `app_providers.dart` which is already imported.

Update `_updateSm2()` — add calls after the for-loop:

```dart
  Future<void> _updateSm2() async {
    final computeUseCase = ref.read(computeSm2UseCaseProvider);
    final updateUseCase = ref.read(updateVocabUseCaseProvider);

    for (final result in widget.result.results) {
      try {
        final word = widget.result.words.firstWhere(
          (w) => w.id == result.vocabRecordId,
        );
        final updated = computeUseCase.compute(word, result.quality);
        await updateUseCase.execute(updated);
      } catch (_) {
        // best-effort: don't crash result screen on SM-2 update failure
      }
    }

    // Record practice stats and reschedule notifications
    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(widget.result.totalCount);
      await ref.read(notificationNotifierProvider.notifier).reschedule();
    } catch (_) {
      // best-effort: don't crash on stats/notification failure
    }
  }
```

- [ ] **Step 2: Update PracticeHomeScreen — add dueCount state + "Ôn hôm nay" button**

In `lib/features/practice/presentation/screens/practice_home_screen.dart`:

Add import (if not already present via app_providers):
```dart
import '../../../../core/di/app_providers.dart';
```

Add `_dueCount` field in `_PracticeHomeScreenState`:
```dart
  int _dueCount = 0;
```

In `initState`, after the existing `addPostFrameCallback`, add a second `addPostFrameCallback` that reads the due count:
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(userSettingsNotifierProvider);
      final stats = ref.read(statsServiceProvider).computeStats();
      setState(() {
        _maxCefrLevel = settings.targetCefrLevel;
        _dueCount = stats.dueCount;
      });
    });
  }
```

Add `_startDueSession` method in `_PracticeHomeScreenState`:
```dart
  Future<void> _startDueSession() async {
    final words = await ref
        .read(getVocabListUseCaseProvider)
        .execute(dueOnly: true);
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có từ nào cần ôn hôm nay.')),
        );
      }
      return;
    }
    final shuffled = List<VocabRecord>.from(words)..shuffle();
    if (mounted) {
      context.go('/practice/session', extra: SessionConfig(words: shuffled));
    }
  }
```

In `build()`, add the "Ôn hôm nay" button above the `Spacer()` + `FilledButton.icon` group:

```dart
            // ── Ôn hôm nay ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _dueCount == 0 ? null : _startDueSession,
                icon: const Icon(Icons.today_outlined),
                label: Text(
                  _dueCount == 0
                      ? 'Hôm nay đã ôn xong ✓'
                      : 'Ôn hôm nay ($_dueCount từ)',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu luyện tập'),
              ),
            ),
```

- [ ] **Step 3: Run flutter analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 4: Run full suite**

```
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```
git add lib/features/practice/presentation/screens/session_result_screen.dart lib/features/practice/presentation/screens/practice_home_screen.dart
git commit -m "feat(plan5): hook stats recording + notification reschedule after session; add Ôn hôm nay button"
```

---

### Task 08: SettingsScreen "Thông báo" Section

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `userSettingsNotifierProvider.reminderEnabled/Hour/Minute` (Task 02)

- [ ] **Step 1: Add "Thông báo" section to SettingsScreen**

In `lib/features/settings/presentation/screens/settings_screen.dart`, inside the `ListView`'s `children` list (after the `'Học tập'` section items, before the closing `]`):

```dart
          // ── Thông báo ─────────────────────────────────────────
          _SectionHeader('Thông báo'),
          SwitchListTile(
            title: const Text('Nhắc nhở hàng ngày'),
            subtitle: const Text('Thông báo khi có từ cần ôn'),
            value: settings.reminderEnabled,
            onChanged: (v) => notifier.setReminderEnabled(enabled: v),
          ),
          if (settings.reminderEnabled)
            ListTile(
              title: const Text('Giờ nhắc cố định'),
              trailing: Text(
                '${settings.reminderHour.toString().padLeft(2, '0')}:'
                '${settings.reminderMinute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              onTap: () => _showTimePicker(context, ref, settings),
            ),
```

Add `_showTimePicker` method inside `SettingsScreen` (it's a `ConsumerWidget`, so add it as a regular method):

```dart
  Future<void> _showTimePicker(
      BuildContext context, WidgetRef ref, UserSettingsState settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (picked == null) return;
    ref
        .read(userSettingsNotifierProvider.notifier)
        .setReminderHour(picked.hour);
    ref
        .read(userSettingsNotifierProvider.notifier)
        .setReminderMinute(picked.minute);
  }
```

Add `UserSettingsState` to the import at the top (already imported via `user_settings_provider.dart`, but the type itself comes from the entity file):

```dart
import '../../../../features/dictionary/domain/entities/user_settings_state.dart';
```

- [ ] **Step 2: Run flutter analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 3: Run full suite**

```
flutter test
```

Expected: all tests pass (66+ tests).

- [ ] **Step 4: Commit**

```
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat(plan5): add Thông báo section to SettingsScreen with reminder toggle and time picker"
```
