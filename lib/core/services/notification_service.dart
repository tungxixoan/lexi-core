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
