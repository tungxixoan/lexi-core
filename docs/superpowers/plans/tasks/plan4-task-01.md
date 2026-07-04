# Plan 4 — Task 01: Package setup + Firebase init + SharedPreferences init

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`

## What this task builds

Add new packages to `pubspec.yaml`, initialize Firebase + SharedPreferences in `main.dart`, and add `sharedPreferencesProvider` to `user_settings_provider.dart` so later tasks can use it. No tests — configuration-only task.

## Files

- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Modify: `.gitignore`
- Generated (by FlutterFire CLI): `lib/firebase_options.dart`

## Interfaces produced

```dart
// In lib/features/dictionary/presentation/providers/user_settings_provider.dart
// New provider added at top of file:
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
// → sharedPreferencesProvider used by Task 02 (UserSettingsNotifier) and Task 07 (SyncService)
```

---

- [ ] **Step 1: Add packages to pubspec.yaml**

Open `pubspec.yaml` and add under `dependencies:` (after `uuid: ^4.5.1`):

```yaml
  shared_preferences: ^2.3.0
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  google_sign_in: ^6.0.0
```

- [ ] **Step 2: Run pub get**

```
flutter pub get
```

Expected: packages resolved, no conflicts.

- [ ] **Step 3: Set up Firebase project (manual — do once)**

Install FlutterFire CLI if not already installed:
```
dart pub global activate flutterfire_cli
```

Run from the project root (requires Firebase CLI logged in):
```
flutterfire configure
```

Select (or create) your Firebase project. This generates:
- `lib/firebase_options.dart` — auto-generated, **commit this file**
- `android/app/google-services.json` — do NOT commit (contains secrets)
- `ios/Runner/GoogleService-Info.plist` — do NOT commit (contains secrets)

Enable **Google Sign-In** in Firebase Console → Authentication → Sign-in method.

- [ ] **Step 4: Add Firebase config files to .gitignore**

Open `.gitignore` and add:
```
# Firebase config (contains secrets)
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

- [ ] **Step 5: Add sharedPreferencesProvider to user_settings_provider.dart**

Open `lib/features/dictionary/presentation/providers/user_settings_provider.dart`. Add these imports and the provider near the top (before `UserSettingsNotifier`):

```dart
import 'package:shared_preferences/shared_preferences.dart';

// Overridden in main.dart with the real SharedPreferences instance.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
```

The `UserSettingsNotifier` class itself is NOT changed in this task — that happens in Task 02.

- [ ] **Step 6: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `user_settings_provider.g.dart` regenerated (now includes `sharedPreferencesProvider`).

- [ ] **Step 7: Update main.dart**

Replace `lib/main.dart` with:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/dictionary/presentation/providers/user_settings_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
```

Note: check the existing `main.dart` for any extra imports (theme path, etc.) and keep them. The key additions are `Firebase.initializeApp()`, `SharedPreferences.getInstance()`, and `sharedPreferencesProvider.overrideWithValue(prefs)` in the `ProviderScope`.

- [ ] **Step 8: Verify app still builds**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 9: Commit**

```
git add pubspec.yaml pubspec.lock lib/main.dart lib/firebase_options.dart lib/features/dictionary/presentation/providers/user_settings_provider.dart lib/features/dictionary/presentation/providers/user_settings_provider.g.dart .gitignore
git commit -m "chore(plan4): add Firebase + SharedPreferences packages and init"
```

## Self-review checklist

- [ ] `sharedPreferencesProvider` is `@Riverpod(keepAlive: true)` and throws `UnimplementedError` (not returns `null`)
- [ ] `main.dart` calls `Firebase.initializeApp()` before `Hive.initFlutter()`
- [ ] `sharedPreferencesProvider.overrideWithValue(prefs)` is inside `ProviderScope(overrides: [...])`
- [ ] `google-services.json` and `GoogleService-Info.plist` are in `.gitignore`
- [ ] `lib/firebase_options.dart` IS committed (it contains no secrets)
- [ ] `flutter analyze lib/` passes with no errors
