import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_hub_screen.dart';

Widget _buildHub() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const ReadingHubScreen()),
      GoRoute(
        path: '/reading/bilingual',
        builder: (ctx, state) => const Scaffold(body: Text('Bilingual home')),
      ),
      GoRoute(
        path: '/reading/part5',
        builder: (ctx, state) => const Scaffold(body: Text('Part5 home')),
      ),
      GoRoute(
        path: '/reading/part6',
        builder: (ctx, state) => const Scaffold(body: Text('Part6 home')),
      ),
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice hub')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows all 3 cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Đọc & gõ'), findsOneWidget);
    expect(find.text('Part 5 — Điền câu'), findsOneWidget);
    expect(find.text('Part 6 — Điền đoạn văn'), findsOneWidget);
  });

  testWidgets('tapping Đọc & gõ navigates to the bilingual home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đọc & gõ'));
    await tester.pumpAndSettle();
    expect(find.text('Bilingual home'), findsOneWidget);
  });

  testWidgets('tapping Part 5 navigates to Part5 home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part 5 — Điền câu'));
    await tester.pumpAndSettle();
    expect(find.text('Part5 home'), findsOneWidget);
  });

  testWidgets('tapping Part 6 navigates to Part6 home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part 6 — Điền đoạn văn'));
    await tester.pumpAndSettle();
    expect(find.text('Part6 home'), findsOneWidget);
  });
}
