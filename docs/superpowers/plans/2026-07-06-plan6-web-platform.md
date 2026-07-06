# LexiCore Plan 6 — Flutter Web Enablement + Adaptive Navigation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Flutter Web as a supported platform, guard platform-incompatible notification code, and replace the fixed bottom NavigationBar with an adaptive layout (NavigationBar on mobile, NavigationRail on tablet/desktop).

**Architecture:** `kIsWeb` guards wrap all `flutter_local_notifications` calls so the service is a no-op on web. `AppShell` switches between `NavigationBar` (<600dp) and `NavigationRail` (≥600dp, extended at ≥1200dp) using `LayoutBuilder`. A new `showReadingPracticeOnMobile` flag in `UserSettingsState` enables the reading tab (Plan 7) on mobile via an opt-in Settings toggle.

**Tech Stack:** Flutter Web (new platform), `flutter/foundation.dart` (`kIsWeb`), GoRouter, Riverpod 2.x, `SharedPreferences`

**BASE commit:** `<SET_AT_EXECUTION_START>`
**Progress ledger:** `.superpowers/sdd/progress.md`

## Global Constraints

(see `docs/superpowers/plans/tasks/plan6-global-constraints.md`)

---

## File Map

```text
web/                                                    CREATE — flutter create --platforms web output
lib/firebase_options.dart                               MODIFY — add web Firebase config (flutterfire configure)
lib/core/services/notification_service.dart             MODIFY — kIsWeb early return on all 3 methods
lib/features/practice/presentation/providers/
  notification_notifier.dart                            MODIFY — kIsWeb guard in build() and reschedule()
lib/features/dictionary/domain/entities/
  user_settings_state.dart                              MODIFY — add showReadingPracticeOnMobile field
lib/features/dictionary/presentation/providers/
  user_settings_provider.dart                           MODIFY — persist + expose showReadingPracticeOnMobile
lib/features/settings/presentation/screens/
  settings_screen.dart                                  MODIFY — add mobile visibility toggle
lib/core/widgets/app_shell.dart                         MODIFY — LayoutBuilder + NavigationRail for wide screens

test/core/services/notification_service_test.dart       MODIFY — add kIsWeb no-op behaviour tests
test/features/dictionary/presentation/providers/
  user_settings_notifier_test.dart                      MODIFY — add showReadingPracticeOnMobile tests
```

## Task Index

| # | Task | Output |
|---|------|--------|
| 01 | [Add web platform + Firebase web config](tasks/plan6-task-01.md) | `web/` folder, Firebase web options |
| 02 | [kIsWeb guards on notification service/notifier](tasks/plan6-task-02.md) | No-op notifications on web; `flutter build web` passes |
| 03 | [showReadingPracticeOnMobile setting](tasks/plan6-task-03.md) | UserSettingsState field + provider method + Settings toggle |
| 04 | [Adaptive navigation in AppShell](tasks/plan6-task-04.md) | LayoutBuilder: NavigationBar <600dp, NavigationRail ≥600dp |
