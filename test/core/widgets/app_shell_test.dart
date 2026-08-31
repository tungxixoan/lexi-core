import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/core/widgets/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';

Future<Widget> _buildShell() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (ctx, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, state) => const Scaffold(body: Text('Home')),
          ),
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

  testWidgets('shows exactly 4 destinations: Tra từ, Từ vựng, Luyện tập, Cài đặt',
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
