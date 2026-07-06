# Plan 6 — Task 02: kIsWeb Guards on Notification Service/Notifier

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 6 Task 01 (web/ folder exists)

## Global Constraints
(see `plan6-global-constraints.md`)

## What This Task Delivers
Guard all `flutter_local_notifications` calls with `if (kIsWeb) return;` so the notification service is a no-op on web. Verify `flutter build web --release` compiles successfully.

## Files
- Modify: `lib/core/services/notification_service.dart`
- Modify: `lib/features/practice/presentation/providers/notification_notifier.dart`
- Modify: `test/core/services/notification_service_test.dart`

## Produces (used by Task 04)
- `NotificationService.initialize()`, `scheduleAll()`, `cancelAll()` — all return immediately on web
- `NotificationNotifier.build()`, `reschedule()` — both no-ops on web

## Steps

- [ ] **Step 1: Write the failing test first**

Replace the contents of `test/core/services/notification_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/notification_service.dart';

void main() {
  test('NotificationService can be constructed without error', () {
    final service = NotificationService();
    expect(service, isNotNull);
  });

  test('initialize() completes without throwing', () async {
    final service = NotificationService();
    await expectLater(service.initialize(), completes);
  });

  test('cancelAll() completes without throwing', () async {
    final service = NotificationService();
    await expectLater(service.cancelAll(), completes);
  });

  test('scheduleAll() with enabled=false completes without throwing', () async {
    final service = NotificationService();
    await expectLater(
      service.scheduleAll(
        enabled: false,
        hour: 9,
        minute: 0,
        dueCount: 0,
        nextDueAt: null,
      ),
      completes,
    );
  });
}
```

- [ ] **Step 2: Run the tests to confirm they pass on mobile (they should already pass)**

```bash
flutter test test/core/services/notification_service_test.dart
```

Expected: all tests pass (the current service runs on the test host, which is not web).

- [ ] **Step 3: Add kIsWeb guard to notification_service.dart**

Replace `lib/core/services/notification_service.dart` with:

```dart
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (kIsWeb) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    if (kIsWeb) return;
    if (!enabled) {
      await cancelAll();
      return;
    }

    await _plugin.cancel(_smartId);
    await _plugin.cancel(_fixedId);

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
    if (kIsWeb) return;
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

- [ ] **Step 4: Add kIsWeb guard to notification_notifier.dart**

Replace `lib/features/practice/presentation/providers/notification_notifier.dart` with:

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (kIsWeb) return;
    _service.initialize();
    ref.listen(userSettingsNotifierProvider, (_, __) => reschedule());
    Future.microtask(reschedule);
  }

  Future<void> reschedule() async {
    if (kIsWeb) return;
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
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final nextReviewRaw = map['nextReviewAt'] as String?;
        if (nextReviewRaw == null) continue;
        final dt = DateTime.parse(nextReviewRaw);
        if (dt.isAfter(now)) {
          if (earliest == null || dt.isBefore(earliest)) earliest = dt;
        }
      } catch (_) {}
    }
    return earliest;
  }
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/core/services/notification_service_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 6: Run full test suite to verify no regressions**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 7: Verify web compilation**

```bash
flutter build web --release
```

Expected: build succeeds, output in `build/web/`. If it fails with `flutter_local_notifications` errors, check that the kIsWeb guards were added correctly — the package has web stubs but some versions may fail; if so, add `flutter_local_notifications` to `dependency_overrides` in `pubspec.yaml` pointing to the web-compatible version, but first try with the current version.

- [ ] **Step 8: Analyze the modified files**

```bash
flutter analyze lib/core/services/notification_service.dart lib/features/practice/presentation/providers/notification_notifier.dart
```

Expected: no issues found.

- [ ] **Step 9: Commit**

```bash
git add lib/core/services/notification_service.dart \
        lib/features/practice/presentation/providers/notification_notifier.dart \
        lib/features/practice/presentation/providers/notification_notifier.g.dart \
        test/core/services/notification_service_test.dart
git commit -m "feat(plan6): add kIsWeb guards on notification service and notifier"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output (pass/fail counts)
Build: `flutter build web --release` result (success or error)
Concerns: (if any)
