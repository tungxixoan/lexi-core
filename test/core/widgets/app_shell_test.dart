import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/widgets/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';

Future<Widget> _buildShell({
  bool showReadingPracticeOnMobile = false,
  bool showListeningPracticeOnMobile = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (showReadingPracticeOnMobile) 'show_reading_mobile': true,
    if (showListeningPracticeOnMobile) 'show_listening_mobile': true,
  });
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
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows NavigationBar on narrow screen (<600dp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows NavigationRail on wide screen (>=600dp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('hides Reading tab on narrow screen when toggle is off',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.text('Đọc'), findsNothing);
  });

  testWidgets('shows Reading tab on narrow screen when toggle is on',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      await _buildShell(showReadingPracticeOnMobile: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đọc'), findsOneWidget);
  });

  testWidgets('shows Reading tab on wide screen regardless of toggle',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.text('Đọc'), findsOneWidget);
  });

  testWidgets('hides Listening tab on narrow screen when toggle is off',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.text('Luyện nghe'), findsNothing);
  });

  testWidgets('shows Listening tab on narrow screen when toggle is on',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      await _buildShell(showListeningPracticeOnMobile: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Luyện nghe'), findsOneWidget);
  });

  testWidgets('shows Listening tab on wide screen regardless of toggle',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.text('Luyện nghe'), findsOneWidget);
  });
}
