// lib/main.dart
// TODO(plan4-task-01): Once `flutterfire configure` has been run and
// lib/firebase_options.dart exists, uncomment the two lines below:
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/dictionary/presentation/providers/user_settings_provider.dart';

void main() async {
  tz.initializeTimeZones();
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(plan4-task-01): Uncomment once firebase_options.dart is generated:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox<String>('vocab_records');
  await Hive.openBox<String>('topics');
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const LexiCoreApp(),
  ));
}

class LexiCoreApp extends StatelessWidget {
  const LexiCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LexiCore',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
