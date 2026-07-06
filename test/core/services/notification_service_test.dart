import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/notification_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

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
