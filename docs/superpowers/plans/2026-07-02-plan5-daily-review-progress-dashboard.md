# LexiCore Plan 5 — Daily Review + Progress Dashboard

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.
> Individual task briefs are in `docs/superpowers/plans/tasks/plan5-task-{01..08}.md`.
> Global constraints: `docs/superpowers/plans/tasks/plan5-global-constraints.md`.

**Goal:** Add a ProgressScreen with SM-2 learning stats + "Ôn hôm nay" mode that filters vocab by due date + two daily local notifications (smart on first due word, fixed at user-set time) with Duolingo-style troll messages when nothing is due.

**Architecture:** `StatsService` (plain Dart class) reads Hive `vocab_records` + SharedPreferences synchronously to compute `LearningStats` and record session history. `NotificationService` wraps `flutter_local_notifications` to schedule notification ID 1 (one-time at `nextReviewAt`) and ID 2 (daily at user-set time). `NotificationNotifier` (keepAlive Riverpod) reschedules on settings change + on app resume. `ProgressScreen` at `/practice/progress` opened via 📊 icon on PracticeHomeScreen AppBar.

**Tech Stack:** Flutter 3.x + Dart 3.x, Riverpod 2.x (`@riverpod` annotation), Hive, SharedPreferences, `flutter_local_notifications ^17.0.0`, `timezone ^0.9.4`, GoRouter.

**BASE commit:** `64a1038`
**Progress ledger:** `.superpowers/sdd/progress.md`

## Global Constraints

- Flutter 3.x + Dart 3.x, iOS and Android only
- Riverpod 2.x: `@Riverpod(keepAlive: true)` for long-lived providers; `ref.read()` in async/callbacks; `ref.watch()` only in `build()`
- New packages: `flutter_local_notifications: ^17.0.0`, `timezone: ^0.9.4`
- Mastered threshold: `sm2Interval >= 21` (days)
- Due threshold: `nextReviewAt == null || nextReviewAt!.isBefore(DateTime.now())`
- Streak: increments on completing ≥1 session that calendar day; resets to 0 if a day is skipped
- Notification ID 1 = smart (one-time), ID 2 = fixed daily repeat
- All UI copy in Vietnamese
- NEVER store `geminiApiKey` in Firestore (unchanged from Plan 4)
- No new Hive boxes; no Firebase changes

## SharedPreferences Keys Added

| Key | Type | Default |
| --- | ---- | ------- |
| `reminder_enabled` | bool | false |
| `reminder_hour` | int | 20 |
| `reminder_minute` | int | 0 |
| `last_practiced_date` | String | `''` |
| `current_streak` | int | 0 |
| `weekly_review_log` | String (JSON) | `'{}'` |

---

## File Map

```text
lib/
├── core/
│   ├── di/app_providers.dart                     MODIFY — add statsService/getLearningStats/learningStats providers
│   ├── services/
│   │   ├── stats_service.dart                    CREATE — StatsService(vocabBox, prefs)
│   │   └── notification_service.dart             CREATE — NotificationService wrapping flutter_local_notifications
│   └── widgets/app_shell.dart                    MODIFY — ConsumerStatefulWidget + WidgetsBindingObserver
├── features/
│   ├── dictionary/domain/entities/
│   │   └── user_settings_state.dart              MODIFY — add reminderEnabled/Hour/Minute fields
│   ├── practice/
│   │   ├── domain/entities/
│   │   │   └── learning_stats.dart               CREATE — LearningStats entity
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── notification_notifier.dart    CREATE — @Riverpod(keepAlive:true), reschedule()
│   │       └── screens/
│   │           ├── progress_screen.dart          CREATE — streak, stats cards, 7-day chart, CEFR breakdown
│   │           ├── practice_home_screen.dart     MODIFY — "Ôn hôm nay" OutlinedButton, AppBar 📊 icon
│   │           └── session_result_screen.dart    MODIFY — recordPracticeSession + reschedule after SM-2
│   ├── settings/presentation/screens/
│   │   └── settings_screen.dart                  MODIFY — "Thông báo" section: toggle + time picker
│   └── vocabulary/
│       ├── domain/repositories/
│       │   └── vocab_repository.dart             MODIFY — add dueOnly param to getAll()
│       └── data/repositories/
│           └── vocab_repository_impl.dart        MODIFY — filter by nextReviewAt when dueOnly:true

test/
├── core/services/
│   ├── stats_service_test.dart                   CREATE — 4 tests
│   └── notification_service_test.dart            CREATE — 2 constructor tests
└── features/dictionary/presentation/providers/
    └── lookup_provider_test.mocks.dart           MODIFY — add dueOnly:false param to mock
```

## Task Index

| # | Task | Key Deliverables |
| --- | ---- | ---------------- |
| 01 | [Packages + Platform Config](tasks/plan5-task-01.md) | `flutter_local_notifications`, `timezone`, AndroidManifest receivers, `tz.initializeTimeZones()` |
| 02 | [UserSettingsState Reminder Fields](tasks/plan5-task-02.md) | `reminderEnabled/Hour/Minute` fields + atomic `setReminderTime()` setter |
| 03 | [dueOnly Filter](tasks/plan5-task-03.md) | `VocabRepository.getAll(dueOnly:)` + UseCase + mock patch |
| 04 | [LearningStats + StatsService + DI](tasks/plan5-task-04.md) | `LearningStats`, `StatsService`, `learningStatsProvider` |
| 05 | [ProgressScreen UI + Route](tasks/plan5-task-05.md) | ProgressScreen, `/practice/progress`, AppBar 📊 icon |
| 06 | [NotificationService + Notifier + AppShell](tasks/plan5-task-06.md) | `NotificationService`, `NotificationNotifier`, AppShell lifecycle observer |
| 07 | [SessionResult Hook + Ôn hôm nay Button](tasks/plan5-task-07.md) | Stats recording, notification reschedule, "Ôn hôm nay" OutlinedButton |
| 08 | [SettingsScreen Thông báo Section](tasks/plan5-task-08.md) | Reminder toggle + conditional time picker in SettingsScreen |
