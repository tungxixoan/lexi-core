// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/dictionary/presentation/providers/user_settings_provider.dart';

void main() async {
  tz.initializeTimeZones();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const LexiCoreApp(),
  ));
}

class LexiCoreApp extends ConsumerWidget {
  const LexiCoreApp({super.key, this.routerConfig});

  /// Injectable in tests so a dummy router can stand in for the real
  /// [appRouter], whose lazy top-level init touches FirebaseAuth. `null` in
  /// production — `main()` constructs `const LexiCoreApp()` and the real
  /// [appRouter] is used.
  final RouterConfig<Object>? routerConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      userSettingsNotifierProvider.select((s) => s.themePreference),
    );
    return MaterialApp.router(
      title: 'LexiCore',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: routerConfig ?? appRouter,
      // SelectionArea needs an Overlay ancestor, but the router's own
      // Overlay (inside its Navigator) sits *below* this builder's child,
      // not above it — so we supply an explicit one here.
      builder: (context, child) => Overlay(
        initialEntries: [
          OverlayEntry(builder: (context) => SelectionArea(child: child!)),
        ],
      ),
    );
  }
}
