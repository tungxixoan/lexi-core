import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/core/widgets/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';

Future<Widget> _buildShell({String initialLocation = '/'}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Scaffold stub(String label) => Scaffold(body: Text(label));
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (ctx, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (ctx, state) => stub('Home')),
          GoRoute(path: '/vocab', builder: (ctx, state) => stub('Vocab')),
          GoRoute(path: '/practice', builder: (ctx, state) => stub('Practice')),
          GoRoute(
            path: '/reading',
            builder: (ctx, state) => stub('Reading'),
            routes: [
              GoRoute(
                path: 'part5',
                builder: (ctx, state) => stub('Part 5'),
                routes: [
                  GoRoute(
                      path: 'session',
                      builder: (ctx, state) => stub('Part 5 session')),
                ],
              ),
            ],
          ),
          GoRoute(
              path: '/listening', builder: (ctx, state) => stub('Listening')),
          GoRoute(path: '/settings', builder: (ctx, state) => stub('Settings')),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows BloomBottomNav on narrow screen (<600dp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.byType(BloomScaffold), findsOneWidget);
    expect(find.byType(BloomBottomNav), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows BloomNavRail on wide screen (>=600dp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.byType(BloomNavRail), findsOneWidget);
    expect(find.byType(BloomBottomNav), findsNothing);
  });

  testWidgets(
      'shows exactly 4 destinations: Tra từ, Từ vựng, Luyện tập, Cài đặt',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.text('Tra từ'), findsOneWidget);
    expect(find.text('Từ vựng'), findsOneWidget);
    expect(find.text('Luyện tập'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Đọc'), findsNothing);
    expect(find.text('Luyện nghe'), findsNothing);
  });

  testWidgets('"Luyện tập" stays selected on /reading and /listening routes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final loc in ['/reading', '/reading/part5/session', '/listening']) {
      await tester.pumpWidget(await _buildShell(initialLocation: loc));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BloomBottomNav>(find.byType(BloomBottomNav))
            .selectedIndex,
        2,
        reason: 'expected "Luyện tập" (index 2) selected at $loc',
      );
    }
  });

  testWidgets('bottom nav does not overflow on a 360dp-wide phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tra từ'), findsOneWidget);
    expect(find.text('Từ vựng'), findsOneWidget);
    expect(find.text('Luyện tập'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
  });
}
