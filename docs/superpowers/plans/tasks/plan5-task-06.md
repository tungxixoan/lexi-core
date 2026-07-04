# Plan 5 — Task 06: NotificationService + NotificationNotifier + AppShell Observer

**Context:** Task 06 of Plan 5. Tasks 01–05 must be complete. See `plan5-global-constraints.md` for project-wide rules.

**Files:**
- Create: `lib/core/services/notification_service.dart`
- Create: `lib/features/practice/presentation/providers/notification_notifier.dart`
- Generated: `lib/features/practice/presentation/providers/notification_notifier.g.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Create: `test/core/services/notification_service_test.dart`

**Interfaces:**
- Consumes:
  - `userSettingsNotifierProvider` (Task 02) — reads `reminderEnabled`, `reminderHour`, `reminderMinute`
  - `getLearningStatsUseCaseProvider` (Task 04) — reads `dueCount`
  - `flutter_local_notifications` and `timezone` (Task 01)
- Produces:
  - `NotificationService` — plain Dart class
    - `.initialize() → Future<void>`
    - `.scheduleAll({required bool enabled, required int hour, required int minute, required int dueCount, required DateTime? nextDueAt}) → Future<void>`
    - `.cancelAll() → Future<void>`
  - `notificationNotifierProvider` — `@Riverpod(keepAlive: true)`, void state
    - `.reschedule() → Future<void>` — public method called from SessionResultScreen (Task 07) and AppShell (this task)
  - `AppShell` — changed from `StatelessWidget` to `ConsumerStatefulWidget` with `WidgetsBindingObserver` to call `reschedule()` on app resume

**Notification rules:**
- Channel ID: `lexi_core_reminders`
- Notification ID 1 = smart (one-time, fires at earliest `nextReviewAt` that is after now)
- Notification ID 2 = fixed daily (fires at user hour:minute, repeats via `matchDateTimeComponents: DateTimeComponents.time`)
- 5 troll message pairs for ID 2 when dueCount == 0; pick by `DateTime.now().millisecond % 5`
- If `enabled == false` → `cancelAll()` and return; skip scheduling

---

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

Expected: `notification_notifier.g.dart` generated alongside the notifier file.

- [ ] **Step 6: Replace AppShell**

Replace the full content of `lib/core/widgets/app_shell.dart`. The current file is a `StatelessWidget` — it must become a `ConsumerStatefulWidget` with `WidgetsBindingObserver`:

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

**Note:** Preserve the exact same NavigationBar destinations and navigation logic as the current AppShell. Read the current file before replacing to verify the destination labels and routes match.

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
git add lib/core/services/notification_service.dart \
        lib/features/practice/presentation/providers/notification_notifier.dart \
        lib/features/practice/presentation/providers/notification_notifier.g.dart \
        lib/core/widgets/app_shell.dart \
        test/core/services/notification_service_test.dart
git commit -m "feat(plan5): add NotificationService, NotificationNotifier, and AppShell lifecycle observer"
```

**Report status:** DONE
