import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/widgets/ai_key_missing_card.dart';

Widget _host() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const Scaffold(body: AiKeyMissingCard()),
      ),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const Scaffold(body: Text('Settings stub')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('renders the missing-API-key message', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping "Mở Cài đặt" navigates to /settings', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mở Cài đặt'));
    await tester.pumpAndSettle();

    expect(find.text('Settings stub'), findsOneWidget);
  });
}
