# Plan 2 — Task 08: App Shell + Bottom Navigation

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 06 (providers available)

## Global Constraints
(see `plan2-global-constraints.md`)
- Navigation: GoRouter only — no `Navigator.push`
- Use GoRouter's `ShellRoute` for the persistent bottom nav

## What This Task Delivers
1. `AppShell` — a `StatelessWidget` that wraps the active screen and shows a `NavigationBar` with two destinations: Dictionary (index 0) and Vocab Bank (index 1).
2. Updates `app_router.dart` to wrap existing routes in a `ShellRoute` and add `/vocab` and `/vocab/:id` paths.
3. Placeholder screens for `VocabBankScreen` and `VocabDetailScreen` so the router compiles. (Real implementations come in Tasks 09 & 10.)

## Files
- Create: `lib/core/widgets/app_shell.dart`
- Modify: `lib/core/router/app_router.dart`
- Create: `lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart` (placeholder)
- Create: `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart` (placeholder)

## Interfaces From Prior Tasks

```dart
// From Plan 1 lookup_screen.dart:
class LookupScreen extends StatelessWidget/ConsumerWidget { ... }

// From Task 06 (providers available but not consumed here):
// vocabBankNotifierProvider, topicsNotifierProvider

// GoRouter API:
// ShellRoute(builder: (ctx, state, child) => ..., routes: [...])
// GoRoute(path: '/', builder: ...)
// GoRouterState.of(context).matchedLocation → String
// context.go('/path')
```

## Produces (used by Tasks 09, 10)

```dart
// lib/core/widgets/app_shell.dart
class AppShell extends StatelessWidget {
  const AppShell({required Widget child});
  // NavigationBar with 2 destinations: Dictionary (index 0), Vocab Bank (index 1)
}

// Updated router paths:
// / → LookupScreen (wrapped in AppShell)
// /vocab → VocabBankScreen (wrapped in AppShell)
// /vocab/:id → VocabDetailScreen(id: ...) (wrapped in AppShell)

// lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart
class VocabBankScreen extends StatelessWidget { ... }  // placeholder

// lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart
class VocabDetailScreen extends StatelessWidget {
  const VocabDetailScreen({required String id});
}  // placeholder
```

## Steps

- [ ] **Step 1: Create app_shell.dart**

```dart
// lib/core/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/vocab')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/vocab');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Vocab Bank',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create placeholder vocab_bank_screen.dart**

```dart
// lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart
import 'package:flutter/material.dart';

class VocabBankScreen extends StatelessWidget {
  const VocabBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Vocab Bank — coming in Task 09')),
    );
  }
}
```

- [ ] **Step 3: Create placeholder vocab_detail_screen.dart**

```dart
// lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart
import 'package:flutter/material.dart';

class VocabDetailScreen extends StatelessWidget {
  const VocabDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocab Detail')),
      body: Center(child: Text('Detail for: $id — coming in Task 10')),
    );
  }
}
```

- [ ] **Step 4: Read existing app_router.dart**

Read `lib/core/router/app_router.dart` to understand the current router structure before modifying it.

- [ ] **Step 5: Replace app_router.dart with ShellRoute version**

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_bank_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LookupScreen(),
        ),
        GoRoute(
          path: '/vocab',
          builder: (context, state) => const VocabBankScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => VocabDetailScreen(
                id: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
```

- [ ] **Step 6: Verify**

```bash
flutter analyze lib/core/ lib/features/vocabulary/presentation/screens/
```

Expected: no errors.

- [ ] **Step 7: Build to verify no runtime issues**

```bash
flutter build apk --debug
```

Expected: builds successfully.

- [ ] **Step 8: Commit**

```bash
git add lib/core/widgets/app_shell.dart \
        lib/core/router/app_router.dart \
        lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart \
        lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart
git commit -m "feat(plan2): add AppShell NavigationBar, ShellRoute, /vocab routes (placeholders)"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Build: flutter build apk --debug success
Concerns: (if any)
