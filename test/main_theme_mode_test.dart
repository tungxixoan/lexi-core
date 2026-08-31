import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/main.dart';

void main() {
  testWidgets('MaterialApp.themeMode follows themePreference', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_preference': 'dark'});
    final prefs = await SharedPreferences.getInstance();
    final dummyRouter = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: LexiCoreApp(routerConfig: dummyRouter),
    ));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('defaults to ThemeMode.system when no pref stored', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dummyRouter = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: LexiCoreApp(routerConfig: dummyRouter),
    ));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });
}
