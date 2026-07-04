# Plan 5: Daily Review + Progress Dashboard — Task Index

**Full Plan:** `docs/superpowers/plans/2026-07-02-plan5-daily-review-progress-dashboard.md`
**Spec:** `docs/superpowers/specs/2026-07-02-plan5-daily-review-progress-dashboard-design.md`

## Tasks

| # | Task | Key Deliverables |
|---|------|-----------------|
| 01 | [Packages + Platform Config](plan5-task-01.md) | `flutter_local_notifications`, `timezone`, AndroidManifest, `tz.initializeTimeZones()` |
| 02 | [UserSettingsState Reminder Fields](plan5-task-02.md) | `reminderEnabled/Hour/Minute` fields + setters |
| 03 | [dueOnly Filter](plan5-task-03.md) | `VocabRepository.getAll(dueOnly:)` + UseCase + mock patch |
| 04 | [LearningStats + StatsService + DI](plan5-task-04.md) | `LearningStats`, `StatsService`, `learningStatsProvider` |
| 05 | [ProgressScreen UI + Route](plan5-task-05.md) | ProgressScreen, `/practice/progress`, AppBar 📊 icon |
| 06 | [NotificationService + Notifier + AppShell](plan5-task-06.md) | `NotificationService`, `NotificationNotifier`, AppShell lifecycle |
| 07 | [SessionResult Hook + Ôn hôm nay Button](plan5-task-07.md) | Stats recording, notification reschedule, "Ôn hôm nay" button |
| 08 | [SettingsScreen Thông báo Section](plan5-task-08.md) | Reminder toggle + time picker in SettingsScreen |

## Dependency Order

```
01 (packages) → 02 (settings fields) → 03 (dueOnly filter)
                                     → 04 (stats) → 05 (UI)
                                                   → 06 (notifications)
                                                              → 07 (session hook)
                                                              → 08 (settings UI)
```

Tasks 02 and 03 can run sequentially after 01. Tasks 05-08 all depend on 04. Tasks 07 and 08 both depend on 06.

## Global Constraints

See `plan5-global-constraints.md`
