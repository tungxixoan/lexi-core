# Plan 6 — Task 04: Adaptive Navigation in AppShell

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 6 Task 03 complete (`showReadingPracticeOnMobile` field exists on `UserSettingsState`)

## Global Constraints
(see `plan6-global-constraints.md`)

## What This Task Delivers
Replace the hardcoded `NavigationBar` in `AppShell` with an adaptive layout: `NavigationBar` at the bottom for screens <600dp (mobile), `NavigationRail` on the left for screens ≥600dp (tablet/desktop), extended at ≥1200dp. Icon set updated: Vocab Bank changes to `library_books` to free up `menu_book` for the reading tab (added in Plan 7 Task 03).

## Files
- Modify: `lib/core/widgets/app_shell.dart`

## Produces (used by Plan 7 Task 03)
- `AppShell` — adaptive nav with 4 destinations; accepts additional destinations in Plan 7

## Steps

- [ ] **Step 1: Write the widget test**

Create `test/core/widgets/app_shell_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/core/widgets/app_shell_test.dart
```

Expected: FAIL — current AppShell always shows NavigationBar.

- [ ] **Step 3: Replace app_shell.dart with adaptive version**

Replace `lib/core/widgets/app_shell.dart` with:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/practice/presentation/providers/notification_notifier.dart';

class _Dest {
  const _Dest({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _kDefaultDests = [
  _Dest(
    path: '/',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    label: 'Dictionary',
  ),
  _Dest(
    path: '/vocab',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
    label: 'Vocab Bank',
  ),
  _Dest(
    path: '/practice',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    label: 'Luyện tập',
  ),
  _Dest(
    path: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Cài đặt',
  ),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb && state == AppLifecycleState.resumed) {
      ref.read(notificationNotifierProvider.notifier).reschedule();
    }
  }

  List<_Dest> _destinations() => _kDefaultDests;

  int _selectedIndex(BuildContext context, List<_Dest> dests) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = dests.length - 1; i >= 0; i--) {
      final p = dests[i].path;
      if (p == '/' ? location == '/' : location.startsWith(p)) return i;
    }
    return 0;
  }

  void _navigateTo(BuildContext context, int index, List<_Dest> dests) {
    if (index < dests.length) context.go(dests[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final dests = _destinations();
    final selectedIndex = _selectedIndex(context, dests);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1200,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) =>
                      _navigateTo(context, i, dests),
                  destinations: dests
                      .map(
                        (d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: widget.child),
              ],
            ),
          );
        }
        return Scaffold(
          body: widget.child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => _navigateTo(context, i, dests),
            destinations: dests
                .map(
                  (d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/core/widgets/app_shell_test.dart
```

Expected: both tests pass.

Note: If the test fails because the `ProviderContainer` can't resolve `sharedPreferencesProvider` or `userSettingsNotifierProvider`, add a mock override for `sharedPreferencesProvider`:

```dart
SharedPreferences.setMockInitialValues({});
final prefs = await SharedPreferences.getInstance();
// then override: sharedPreferencesProvider.overrideWithValue(prefs)
```

Update `_buildShell` accordingly if needed.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/core/widgets/app_shell.dart
```

Expected: no issues found.

- [ ] **Step 7: Verify web build still passes**

```bash
flutter build web --release
```

Expected: builds successfully.

- [ ] **Step 8: Commit**

```bash
git add lib/core/widgets/app_shell.dart \
        test/core/widgets/app_shell_test.dart
git commit -m "feat(plan6): adaptive navigation — NavigationRail on wide screens"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output (pass/fail counts)
Build: flutter build web result
Concerns: (if any)
