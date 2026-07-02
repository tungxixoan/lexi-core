# Plan 5: Daily Review + Progress Dashboard — Design Spec

**Date:** 2026-07-02
**Status:** Approved

---

## Goal

Add a Progress Dashboard (stats screen accessible from the Practice tab) and a Daily Review system consisting of two features: (1) "Ôn hôm nay" mode that filters vocab by SM-2 due date, and (2) smart + fixed daily local notifications that remind the user to review — with Duolingo-style troll messages when nothing is due.

---

## Architecture Overview

Three new subsystems, all following existing LexiCore patterns:

1. **Due-filter** — extend `VocabRepository.getAll()` + `GetVocabListUseCase.execute()` with `dueOnly: bool`
2. **StatsService** — plain Dart class, reads Hive `vocab_records` + SharedPreferences, computes `LearningStats` and records practice history
3. **NotificationService** — plain Dart class wrapping `flutter_local_notifications`, schedules two notifications per day; `NotificationNotifier` (keepAlive) watches settings and reschedules on change; `AppShell` reschedules on app resume

No new Hive boxes. No Firebase involvement.

---

## Global Constraints

- Flutter 3.x + Dart 3.x, iOS and Android only
- Riverpod 2.x with `@riverpod` annotation; `@Riverpod(keepAlive: true)` for long-lived providers
- `ref.read()` inside async/callbacks; `ref.watch()` only in `build()`
- `addPostFrameCallback` for navigation from `build()`
- New packages: `flutter_local_notifications: ^17.0.0`, `timezone: ^0.9.4`
- SharedPreferences for all persistence (no new Hive boxes)
- Mastered threshold: `sm2Interval >= 21` (days)
- Due threshold: `nextReviewAt == null || nextReviewAt!.isBefore(DateTime.now())`
  - `nextReviewAt == null` = never reviewed = always due
- Streak: increments when at least 1 practice session is completed that day (any mode); resets to 0 if a calendar day is skipped
- Weekly log: keyed by ISO date string `"yyyy-MM-dd"`, value = total words practiced that day (sum across all sessions)
- Notification ID 1 = smart (one-time), ID 2 = fixed daily
- NEVER store `geminiApiKey` in Firestore (existing constraint, unchanged)
- All UI copy in Vietnamese (matching existing app)

---

## SharedPreferences Keys (new in Plan 5)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `reminder_enabled` | bool | false | Toggle for daily notifications |
| `reminder_hour` | int | 20 | Hour for fixed daily notification (0–23) |
| `reminder_minute` | int | 0 | Minute for fixed daily notification (0–59) |
| `last_practiced_date` | String | '' | ISO date `"yyyy-MM-dd"` of last session |
| `current_streak` | int | 0 | Consecutive days with at least 1 session |
| `weekly_review_log` | String | '{}' | JSON: `{"2026-07-02": 5, "2026-07-01": 3, ...}` |

---

## Data Model

### `LearningStats` entity

```dart
// lib/features/practice/domain/entities/learning_stats.dart
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

  final int dueCount;                    // words where nextReviewAt == null || <= now
  final int masteredCount;               // words where sm2Interval >= 21
  final int totalCount;                  // all words in vocab bank
  final Map<CEFRLevel, int> cefrBreakdown; // count per CEFR level
  final int currentStreak;               // consecutive days practiced
  final Map<String, int> weeklyLog;      // "yyyy-MM-dd" → words practiced
}
```

---

## New Files

| File | Purpose |
|------|---------|
| `lib/features/practice/domain/entities/learning_stats.dart` | `LearningStats` data class |
| `lib/core/services/stats_service.dart` | Compute stats from Hive + SharedPrefs; record session |
| `lib/core/services/notification_service.dart` | Schedule/cancel two daily notifications |
| `lib/features/practice/presentation/providers/notification_notifier.dart` | keepAlive Riverpod notifier, watches reminder settings |
| `lib/features/practice/presentation/providers/notification_notifier.g.dart` | Generated |
| `lib/features/practice/presentation/screens/progress_screen.dart` | Stats UI |
| `test/core/services/stats_service_test.dart` | Unit tests for StatsService |
| `test/core/services/notification_service_test.dart` | Unit tests for NotificationService |

---

## Modified Files

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `flutter_local_notifications`, `timezone` |
| `android/app/src/main/AndroidManifest.xml` | Add exact alarm + boot permissions + notification channel |
| `ios/Runner/Info.plist` | No change needed — `flutter_local_notifications` handles permission request at runtime |
| `lib/main.dart` | Add `tz.initializeTimeZones()` before `runApp` |
| `lib/features/dictionary/domain/entities/user_settings_state.dart` | Add `reminderEnabled`, `reminderHour`, `reminderMinute` fields |
| `lib/features/dictionary/presentation/providers/user_settings_provider.dart` | Add 3 setters |
| `lib/features/vocabulary/domain/repositories/vocab_repository.dart` | Add `dueOnly` param to `getAll()` |
| `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart` | Implement `dueOnly` filter |
| `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart` | Pass `dueOnly` through |
| `lib/core/di/app_providers.dart` | Register `StatsService`, `GetLearningStatsUseCase` |
| `lib/core/router/app_router.dart` | Add `/practice/progress` route |
| `lib/features/practice/presentation/screens/practice_home_screen.dart` | Add 📊 icon + "Ôn hôm nay" button |
| `lib/features/practice/presentation/screens/session_result_screen.dart` | Hook `StatsService.recordPracticeSession()` + `NotificationNotifier.reschedule()` after SM-2 |
| `lib/core/widgets/app_shell.dart` | Add `WidgetsBindingObserver`, call `NotificationNotifier.reschedule()` on app resume |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Add "Thông báo" section |

---

## Component Interfaces

### StatsService

```dart
// lib/core/services/stats_service.dart
class StatsService {
  StatsService({required Box<String> vocabBox, required SharedPreferences prefs});

  // Reads all VocabRecords from Hive + streak/weekly from SharedPrefs
  LearningStats computeStats();

  // Call after each session. wordCount = words practiced in that session.
  // Updates current_streak and weekly_review_log in SharedPreferences.
  Future<void> recordPracticeSession(int wordCount);
}
```

`recordPracticeSession` logic:
1. Read `last_practiced_date` from prefs
2. Today's ISO date = `DateFormat('yyyy-MM-dd').format(DateTime.now())`
3. If `last_practiced_date == today` → streak unchanged (already counted today)
4. Else if `last_practiced_date == yesterday` → `current_streak += 1`
5. Else → `current_streak = 1` (missed a day or first time)
6. Write `last_practiced_date = today`, `current_streak = newStreak`
7. Read `weekly_review_log` JSON, add `wordCount` to today's entry, write back
8. Prune `weekly_review_log` to keep only last 7 days

### NotificationService

```dart
// lib/core/services/notification_service.dart
class NotificationService {
  Future<void> initialize();

  // Schedule/update both notifications based on current state.
  // If enabled=false: cancel both.
  // nextDueAt: earliest VocabRecord.nextReviewAt in the future (null if none).
  // dueCount: words due at reminder_hour:reminder_minute (computed by caller).
  Future<void> scheduleAll({
    required bool enabled,
    required int hour,
    required int minute,
    required int dueCount,
    required DateTime? nextDueAt,
  });

  Future<void> cancelAll();
}
```

**Notification 1 (smart — ID 1):** One-time, fires at `nextDueAt`. Title: `"⏰ Đến giờ ôn từ rồi!"`. Body: `"Có từ vừa đến hạn ôn. Mở app để bắt đầu 📚"`. Scheduled only when `nextDueAt != null && enabled`.

**Notification 2 (fixed — ID 2):** Daily at `hour:minute`. Scheduled using `timezone` local timezone. Content:
- `dueCount > 0` → Title: `"📚 Ôn từ hàng ngày"`, Body: `"Bạn có $dueCount từ đang chờ được ôn!"` 
- `dueCount == 0` → Title + Body chosen randomly from troll list (see below). Scheduled even when `dueCount == 0` (always fires at fixed time, content varies).

**Troll messages** (5 options, pick `DateTime.now().millisecond % 5`):

| Title | Body |
|-------|------|
| `"Ổn lắm~ 😏"` | `"Bạn đã ôn xong rồi... nhưng một chút nữa thôi không? 👀"` |
| `"Streak đang cháy 🔥"` | `"Đừng để nó tắt nhé! Học thêm một chút đi~"` |
| `"Không có gì cần ôn hôm nay"` | `"Nhưng thêm từ mới vào bank đi! 📖"` |
| `"Bộ nhớ sẽ mờ dần... 🧠"` | `"Học thêm một chút đi để chắc ăn hơn!"` |
| `"Ổn lắm~ nhưng..."` | `"Duolingo owl đang nhìn bạn đấy 🦉"` |

### NotificationNotifier

```dart
// lib/features/practice/presentation/providers/notification_notifier.dart
@Riverpod(keepAlive: true)
class NotificationNotifier extends _$NotificationNotifier {
  final _service = NotificationService();

  @override
  void build() {
    // Initialize once
    _service.initialize();
    // Watch reminder settings; reschedule when they change
    ref.listen(userSettingsNotifierProvider, (_, __) => reschedule());
    // Bootstrap on first build
    Future.microtask(reschedule);
  }

  Future<void> reschedule() async {
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.reminderEnabled) {
      await _service.cancelAll();
      return;
    }
    // Compute stats to get dueCount and nextDueAt
    final stats = ref.read(getLearningStatsUseCaseProvider).execute();
    // Find earliest future nextReviewAt
    final nextDueAt = _computeNextDueAt(); // reads Hive directly
    await _service.scheduleAll(
      enabled: settings.reminderEnabled,
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      dueCount: stats.dueCount,
      nextDueAt: nextDueAt,
    );
  }
}
```

`_computeNextDueAt()` implementation in `NotificationNotifier`:
```dart
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
```

### GetLearningStatsUseCase

```dart
// lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart
class GetLearningStatsUseCase {
  const GetLearningStatsUseCase(this._statsService);
  final StatsService _statsService;

  LearningStats execute() => _statsService.computeStats();
}
```

Registered in `app_providers.dart`:
```dart
@riverpod
StatsService statsService(StatsServiceRef ref) => StatsService(
  vocabBox: Hive.box<String>('vocab_records'),
  prefs: ref.read(sharedPreferencesProvider),
);

@riverpod
GetLearningStatsUseCase getLearningStatsUseCase(GetLearningStatsUseCaseRef ref) =>
    GetLearningStatsUseCase(ref.read(statsServiceProvider));
```

---

## UserSettingsState changes

Add 3 fields with defaults:

```dart
final bool reminderEnabled;   // default: false
final int reminderHour;       // default: 20
final int reminderMinute;     // default: 0
```

New setters in `UserSettingsNotifier`:
```dart
void setReminderEnabled({required bool enabled}) { ... prefs key: 'reminder_enabled' }
void setReminderHour(int hour) { ... prefs key: 'reminder_hour' }
void setReminderMinute(int minute) { ... prefs key: 'reminder_minute' }
```

`defaults`:
```dart
static const defaults = UserSettingsState(
  ...,
  reminderEnabled: false,
  reminderHour: 20,
  reminderMinute: 0,
);
```

---

## VocabRepository.getAll() change

Add `dueOnly: bool = false` parameter:

```dart
// domain/repositories/vocab_repository.dart
Future<List<VocabRecord>> getAll({
  String? topicId,
  InputType? inputType,
  Language? language,
  CEFRLevel? maxCefrLevel,
  bool dueOnly = false,      // NEW
});

// data/repositories/vocab_repository_impl.dart
if (dueOnly) {
  final now = DateTime.now();
  records = records
      .where((r) => r.nextReviewAt == null || r.nextReviewAt!.isBefore(now))
      .toList();
}
```

`GetVocabListUseCase.execute()` gains `bool dueOnly = false` and passes through.

---

## ProgressScreen UI

Route: `/practice/progress` (inside ShellRoute, `GoRoute` added in `app_router.dart`).

Opened via `IconButton(icon: Icon(Icons.bar_chart_outlined))` in PracticeHomeScreen AppBar.

```dart
// lib/features/practice/presentation/screens/progress_screen.dart
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.read(getLearningStatsUseCaseProvider).execute();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tiến độ học')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Streak banner
          _StreakBanner(streak: stats.currentStreak),
          const SizedBox(height: 16),

          // 2. Due / Mastered row
          Row(children: [
            Expanded(child: _StatCard(
              label: 'Hôm nay',
              value: '${stats.dueCount}',
              icon: Icons.today_outlined,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'Đã thuộc',
              value: '${stats.masteredCount}',
              icon: Icons.military_tech_outlined,
            )),
          ]),
          const SizedBox(height: 12),

          // 3. "Ôn ngay" button (only when dueCount > 0)
          if (stats.dueCount > 0) ...[
            FilledButton.icon(
              onPressed: () => _startDueSession(context, ref),
              icon: const Icon(Icons.play_arrow),
              label: Text('Ôn ${stats.dueCount} từ ngay'),
            ),
            const SizedBox(height: 24),
          ],

          // 4. Weekly chart
          Text('7 ngày qua', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _WeeklyChart(weeklyLog: stats.weeklyLog),
          const SizedBox(height: 24),

          // 5. CEFR breakdown
          Text('Theo cấp độ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _CefrBreakdown(breakdown: stats.cefrBreakdown, total: stats.totalCount),
        ],
      ),
    );
  }

  Future<void> _startDueSession(BuildContext context, WidgetRef ref) async {
    final words = await ref.read(getVocabListUseCaseProvider).execute(dueOnly: true);
    if (words.isEmpty || !context.mounted) return;
    final shuffled = List.of(words)..shuffle();
    context.push('/practice/session', extra: SessionConfig(words: shuffled));
  }
}
```

**`_StreakBanner`**: Shows `"🔥 $streak ngày liên tiếp"`. When `streak == 0`: `"Chưa có streak, bắt đầu hôm nay nhé!"`.

**`_StatCard`**: Card with icon, large number, label below.

**`_WeeklyChart`**: `CustomPaint`, draws 7 bars for the last 7 days. X-axis labels: day abbreviations (`"T2"–"CN"` for Mon–Sun, today shows `"H"`). Bar height proportional to max day count. If all counts = 0, bars are still shown at minimum height 4px.

**`_CefrBreakdown`**: `Column` of `CEFRLevel.values` rows. Each row: label (e.g. `"A1"`), `LinearProgressIndicator` scaled by `count / total`, count number. Skip rows where count = 0 (show as `"0"` with empty bar, don't hide).

---

## PracticeHomeScreen changes

1. **AppBar action**: `IconButton(icon: Icon(Icons.bar_chart_outlined), onPressed: () => context.push('/practice/progress'))`

2. **"Ôn hôm nay" button**: shown above the existing "Bắt đầu luyện tập" button. Fetches due words with `dueOnly: true`. Shows count badge if > 0: `"Ôn hôm nay (5 từ)"`. If 0 due: button still shown but disabled with text `"Hôm nay đã ôn xong ✓"`.

---

## SessionResultScreen changes

In `_updateSm2()`, after the for-loop completes successfully:

```dart
// Record stats + reschedule notifications
final statsService = ref.read(statsServiceProvider);
await statsService.recordPracticeSession(widget.result.totalCount);
await ref.read(notificationNotifierProvider.notifier).reschedule();
```

---

## AppShell changes

Add `WidgetsBindingObserver` mixin, implement `didChangeAppLifecycleState`:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    ref.read(notificationNotifierProvider.notifier).reschedule();
  }
}
```

Register/unregister in `initState`/`dispose`.

---

## SettingsScreen changes

Add "Thông báo" section after "Học tập":

```
_SectionHeader('Thông báo')
SwitchListTile(
  title: 'Nhắc nhở hàng ngày',
  subtitle: 'Thông báo khi có từ cần ôn',
  value: settings.reminderEnabled,
  onChanged: (v) => notifier.setReminderEnabled(enabled: v),
)
if (settings.reminderEnabled)
  ListTile(
    title: 'Giờ nhắc cố định',
    trailing: Text('${settings.reminderHour.toString().padLeft(2,'0')}:${settings.reminderMinute.toString().padLeft(2,'0')}'),
    onTap: () => _showTimePicker(context, ref, settings),
  )
```

`_showTimePicker`: uses Flutter's built-in `showTimePicker()`, saves via `setReminderHour()` + `setReminderMinute()`.

---

## Platform Setup

### Android (`android/app/src/main/AndroidManifest.xml`)

Add inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Add inside `<application>`:
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

### iOS

No `Info.plist` changes needed. `flutter_local_notifications` requests permission at runtime via `requestPermissions()` called inside `NotificationService.initialize()`.

---

## `main.dart` change

```dart
import 'package:timezone/data/latest.dart' as tz;

// In main():
tz.initializeTimeZones();
```

---

## Tests

### `test/core/services/stats_service_test.dart` (4 tests)

1. `computeStats()` returns zeros when vocab box is empty
2. `computeStats()` correctly counts due words (`nextReviewAt == null` and `nextReviewAt <= now`)
3. `computeStats()` correctly counts mastered words (`sm2Interval >= 21`)
4. `recordPracticeSession()` increments streak on consecutive days and resets on gap

### `test/core/services/notification_service_test.dart` (2 tests)

1. `NotificationService` can be constructed without error
2. `cancelAll()` is safe to call before `initialize()`

---

## Task Decomposition (8 tasks)

| Task | Deliverable |
|------|-------------|
| 01 | Packages + platform config + `tz.initializeTimeZones()` |
| 02 | `UserSettingsState` 3 new fields + setters + SharedPrefs keys |
| 03 | `dueOnly` filter in `VocabRepository` + `GetVocabListUseCase` |
| 04 | `LearningStats` entity + `StatsService` + `GetLearningStatsUseCase` + DI |
| 05 | `ProgressScreen` UI + `/practice/progress` route + PracticeHomeScreen 📊 icon |
| 06 | `SessionResultScreen` hook + PracticeHomeScreen "Ôn hôm nay" button |
| 07 | `NotificationService` + `NotificationNotifier` + `AppShell` lifecycle observer |
| 08 | `SettingsScreen` "Thông báo" section |
