import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/widgets/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';

Widget _buildShell(double width) {
  SharedPreferences.setMockInitialValues({});
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
      sharedPreferencesProvider
          .overrideWith((_) => throw UnimplementedError()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows NavigationBar on narrow screen (<600dp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildShell(400));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows NavigationRail on wide screen (>=600dp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildShell(800));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
