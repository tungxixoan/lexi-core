# Plan 4 — Task 05: AppShell 4th tab + /settings route + placeholder SettingsScreen

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01 (packages available). Can run in parallel with Tasks 02–04.

## What this task builds

Adds a 4th "Cài đặt" tab to the navigation bar, a `/settings` GoRoute inside the ShellRoute, and a placeholder `SettingsScreen` (shows a spinner). The full SettingsScreen UI comes in Task 08.

No tests — scaffolding only.

## Files

- Create: `lib/features/settings/presentation/screens/settings_screen.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Modify: `lib/core/router/app_router.dart`

## Interfaces produced

```dart
// class SettingsScreen extends StatelessWidget — at '/settings'
// AppShell now routes index 3 → '/settings'
// GoRoute(path: '/settings') inside ShellRoute
```

---

- [ ] **Step 1: Create placeholder SettingsScreen**

Create `lib/features/settings/presentation/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
```

- [ ] **Step 2: Update AppShell**

Read the existing `lib/core/widgets/app_shell.dart` first to see the current structure, then replace it:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/vocab')) return 1;
    if (location.startsWith('/practice')) return 2;
    if (location.startsWith('/settings')) return 3;
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
            case 2:
              context.go('/practice');
            case 3:
              context.go('/settings');
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
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Luyện tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
```

Note: Match the existing `AppShell` constructor signature and any existing imports.

- [ ] **Step 3: Update AppRouter**

Read the existing `lib/core/router/app_router.dart` to see the current routes, then add the `/settings` route inside `ShellRoute.routes`:

```dart
import '../../features/settings/presentation/screens/settings_screen.dart';
// (add this import alongside existing screen imports)

// Inside ShellRoute.routes, add after the /practice route:
GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsScreen(),
),
```

The full route list inside `ShellRoute.routes` should be:
- `GoRoute(path: '/', ...)` — LookupScreen
- `GoRoute(path: '/vocab', ...)` — VocabBankScreen + /vocab/:id sub-route
- `GoRoute(path: '/practice', ...)` — PracticeHomeScreen + /practice/session + /practice/session/result
- `GoRoute(path: '/settings', ...)` — SettingsScreen (new)

- [ ] **Step 4: Analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 5: Run tests**

```
flutter test
```

Expected: all passing.

- [ ] **Step 6: Commit**

```
git add lib/features/settings/presentation/screens/settings_screen.dart lib/core/widgets/app_shell.dart lib/core/router/app_router.dart
git commit -m "feat(plan4): add Settings tab (4th) and /settings route with placeholder screen"
```

## Self-review checklist

- [ ] `_selectedIndex` returns `3` for `/settings` and paths starting with `/settings`
- [ ] `onDestinationSelected case 3` calls `context.go('/settings')` (not push)
- [ ] `NavigationDestination` for Settings uses `Icons.settings_outlined` / `Icons.settings`
- [ ] `/settings` route is inside `ShellRoute.routes` (not outside — Settings needs the nav bar)
- [ ] `SettingsScreen` has `automaticallyImplyLeading: false` (top-level tab, no back button)
- [ ] `flutter analyze lib/` clean
