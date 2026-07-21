import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/listening/presentation/screens/listening_home_screen.dart';

Widget _buildHub() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ListeningHomeScreen(),
      ),
      GoRoute(
        path: '/listening/dictation',
        builder: (ctx, state) => const Scaffold(body: Text('Dictation home')),
      ),
      GoRoute(
        path: '/listening/comprehension',
        builder: (ctx, state) => const Scaffold(body: Text('Comprehension home')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows both Nghe chép and Nghe hiểu cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Nghe chép'), findsOneWidget);
    expect(find.text('Nghe hiểu'), findsOneWidget);
  });

  testWidgets('tapping Nghe chép navigates to dictation home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghe chép'));
    await tester.pumpAndSettle();
    expect(find.text('Dictation home'), findsOneWidget);
  });

  testWidgets('tapping Nghe hiểu navigates to comprehension home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghe hiểu'));
    await tester.pumpAndSettle();
    expect(find.text('Comprehension home'), findsOneWidget);
  });
}
