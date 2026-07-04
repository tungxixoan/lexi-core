# Plan 5 Global Constraints

These constraints apply to ALL tasks in Plan 5 and are NOT repeated in each task file.

## Platform & Language
- Flutter 3.x + Dart 3.x, iOS and Android only
- No web or desktop targets

## State Management
- Riverpod 2.x with `@riverpod` annotation only
- `@Riverpod(keepAlive: true)` for long-lived providers (NotificationNotifier, UserSettingsNotifier, etc.)
- `ref.read()` inside async callbacks; `ref.watch()` only in `build()`
- `addPostFrameCallback` for navigation/side effects triggered from `build()`

## New Packages (Task 01 installs)
- `flutter_local_notifications: ^17.0.0`
- `timezone: ^0.9.4`

## Storage
- Hive boxes `vocab_records` and `topics` — NO new boxes
- SharedPreferences for stats + settings
- New SharedPreferences keys:
  - `reminder_enabled` (bool, default false)
  - `reminder_hour` (int, default 20)
  - `reminder_minute` (int, default 0)
  - `last_practiced_date` (String, default '')
  - `current_streak` (int, default 0)
  - `weekly_review_log` (String JSON, default '{}')

## Domain Rules
- Mastered threshold: `sm2Interval >= 21` (days)
- Due threshold: `nextReviewAt == null || nextReviewAt!.isBefore(DateTime.now())`
- Streak: increments when completing ≥1 session that calendar day; resets to 1 (not 0) if a day is skipped
- Weekly log: `Map<String, int>` keyed `"yyyy-MM-dd"`, pruned to last 7 days

## Notifications
- Notification ID 1 = smart one-time (fires at earliest `nextReviewAt`)
- Notification ID 2 = fixed daily (fires at user-set hour:minute, repeats via `matchDateTimeComponents: DateTimeComponents.time`)
- 5 Duolingo-style troll messages for ID 2 when dueCount == 0
- Channel ID: `lexi_core_reminders`

## Security
- NEVER store `geminiApiKey` in Firestore — local only (SharedPreferences)

## Code Style
- All UI copy in Vietnamese
- No new comments unless WHY is non-obvious
- No placeholder code, TBD, or TODO in final commits

## Testing
- Use `mocktail` for mocking
- Hive tests: create temp dir, call `Hive.init(tempDir.path)`, tear down with `await Hive.close(); await tempDir.delete(recursive: true)`
- `SharedPreferences.setMockInitialValues({})` before each test that uses SharedPreferences
