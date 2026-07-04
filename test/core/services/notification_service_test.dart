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
