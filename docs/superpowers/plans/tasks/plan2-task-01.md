# Plan 2 — Task 01: Hive + UUID Setup

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 1 complete (existing Flutter project with Riverpod + GoRouter)

## Global Constraints
(see `plan2-global-constraints.md`)
- Hive storage: `Box<String>` with JSON — no Hive code generation
- Package name: `lexi_core`

## What This Task Delivers
Add Hive (local storage) and uuid (ID generation) packages to the project and initialize Hive in `main.dart` before the app starts. This unlocks local persistence for Plans 2, 3, 4.

## Files
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

## Produces (used by Tasks 04, 05, 06)
- `Hive.box<String>('vocab_records')` — open and ready when app starts
- `Hive.box<String>('topics')` — open and ready when app starts
- `uuid` package importable as `import 'package:uuid/uuid.dart'`

## Steps

- [ ] **Step 1: Add dependencies to pubspec.yaml**

In `pubspec.yaml`, under `dependencies:`, add these three lines (keep all existing deps):

```yaml
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  uuid: ^4.5.1
```

- [ ] **Step 2: Run flutter pub get**

```bash
flutter pub get
```

Expected: resolves without error, no version conflicts.

- [ ] **Step 3: Update main.dart**

Replace the entire contents of `lib/main.dart` with:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('vocab_records');
  await Hive.openBox<String>('topics');
  runApp(const ProviderScope(child: LexiCoreApp()));
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

- [ ] **Step 4: Verify build**

```bash
flutter analyze lib/main.dart
```

Expected: no errors.

- [ ] **Step 5: Verify app still runs**

```bash
flutter build apk --debug
```

Expected: builds successfully (no need to run on device).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "feat(plan2): add Hive + uuid deps, async Hive init in main"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Build: flutter analyze output
Concerns: (if any)
