# Task 11: App Shell (Theme + Router + main.dart)

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 10 (providers exist, build_runner has run)

## Global Constraints
- Navigation: GoRouter only
- Material3 design system

## What This Task Delivers
App theme, GoRouter config, and `main.dart`. Also creates a **placeholder** `LookupScreen` so the app compiles — Task 15 will replace it.

## Files
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/router/app_router.dart`
- Create: `lib/main.dart`
- Create: `lib/features/dictionary/presentation/screens/lookup_screen.dart` *(placeholder only)*

## Steps

- [ ] **Step 1: Create app_theme.dart**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF5B7FFF);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
  );
}
```

- [ ] **Step 2: Create placeholder lookup_screen.dart**

```dart
// lib/features/dictionary/presentation/screens/lookup_screen.dart
import 'package:flutter/material.dart';

class LookupScreen extends StatelessWidget {
  const LookupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('LexiCore — coming soon')),
    );
  }
}
```

- [ ] **Step 3: Create app_router.dart**

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LookupScreen(),
    ),
  ],
);
```

- [ ] **Step 4: Create main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
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

- [ ] **Step 5: Verify app builds**

```bash
flutter build apk --debug
```

Expected: build succeeds (warnings OK, errors not OK).

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/ lib/core/router/ lib/main.dart \
        lib/features/dictionary/presentation/screens/lookup_screen.dart
git commit -m "feat: add app shell — theme, router, main.dart, placeholder LookupScreen"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: N/A (build verification only)
Concerns: (if any)
