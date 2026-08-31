import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/practice/presentation/screens/practice_hub_screen.dart';

Widget _buildHub() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const PracticeHubScreen()),
      GoRoute(
        path: '/practice/vocab',
        builder: (ctx, state) => const Scaffold(body: Text('Vocab practice home')),
      ),
      GoRoute(
        path: '/reading',
        builder: (ctx, state) => const Scaffold(body: Text('Reading home')),
      ),
      GoRoute(
        path: '/listening',
        builder: (ctx, state) => const Scaffold(body: Text('Listening home')),
      ),
      GoRoute(
        path: '/practice/progress',
        builder: (ctx, state) => const Scaffold(body: Text('Progress screen')),
      ),
      GoRoute(
        path: '/practice/radar',
        builder: (ctx, state) => const Scaffold(body: Text('Word Radar screen')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

void main() {
  testWidgets('shows all 5 hub cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Từ vựng cách khoảng'), findsOneWidget);
    expect(find.text('Luyện đọc'), findsOneWidget);
    expect(find.text('Luyện nghe'), findsOneWidget);
    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(find.text('Quét từ vựng'), findsOneWidget);
    expect(find.byType(BloomScaffold), findsOneWidget);
  });

  testWidgets('tapping Quét từ vựng navigates to /practice/radar', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quét từ vựng'));
    await tester.pumpAndSettle();
    expect(find.text('Word Radar screen'), findsOneWidget);
  });
}
