# Plan 3 — Task 04: Practice DI + Navigation + Placeholder Screens

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 03 (`ExerciseGeneratorSource`, `GenerateExerciseUseCase`, `ComputeSm2UseCase`)

## Global Constraints
(see `plan3-global-constraints.md`)
- Riverpod: `@riverpod` annotation only
- GoRouter: no `Navigator.push`
- Run `dart run build_runner build --delete-conflicting-outputs` after editing `app_providers.dart`

## What This Task Delivers

- 3 new Riverpod providers: `exerciseGeneratorSourceProvider`, `generateExerciseUseCaseProvider`, `computeSm2UseCaseProvider`
- `/practice` routes wired into existing `ShellRoute`
- 3rd NavigationBar tab: "Luyện tập" (`Icons.school_outlined`)
- 3 placeholder screens (replace with real UI in Tasks 07-09)

## Files

- Modify: `lib/core/di/app_providers.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Create: `lib/features/practice/presentation/screens/practice_home_screen.dart`
- Create: `lib/features/practice/presentation/screens/practice_session_screen.dart`
- Create: `lib/features/practice/presentation/screens/session_result_screen.dart`

## Step 1: Add practice DI providers to app_providers.dart

Add these imports (after Plan 2 imports):
```dart
// --- Practice DI (Plan 3) ---
import '../../features/practice/data/sources/exercise_generator_source.dart';
import '../../features/practice/domain/use_cases/compute_sm2_use_case.dart';
import '../../features/practice/domain/use_cases/generate_exercise_use_case.dart';
```

Add these providers at the bottom:
```dart
@riverpod
ExerciseGeneratorSource exerciseGeneratorSource(ExerciseGeneratorSourceRef ref) {
  final apiKey = ref.watch(
    userSettingsNotifierProvider.select((s) => s.geminiApiKey),
  );
  return ExerciseGeneratorSource(apiKey: apiKey);
}

@riverpod
GenerateExerciseUseCase generateExerciseUseCase(GenerateExerciseUseCaseRef ref) =>
    GenerateExerciseUseCase(ref.watch(exerciseGeneratorSourceProvider));

@riverpod
ComputeSm2UseCase computeSm2UseCase(ComputeSm2UseCaseRef ref) =>
    const ComputeSm2UseCase();
```

## Step 2: Run build_runner

```
dart run build_runner build --delete-conflicting-outputs
```

## Step 3: Create placeholder screens

```dart
// lib/features/practice/presentation/screens/practice_home_screen.dart
import 'package:flutter/material.dart';
import '../../domain/entities/exercise_result.dart';

class PracticeHomeScreen extends StatelessWidget {
  const PracticeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Practice — coming soon')));
}
```

```dart
// lib/features/practice/presentation/screens/practice_session_screen.dart
import 'package:flutter/material.dart';
import '../../domain/entities/exercise_result.dart';

class PracticeSessionScreen extends StatelessWidget {
  const PracticeSessionScreen({super.key, required this.config});
  final SessionConfig config;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Session — coming soon')));
}
```

```dart
// lib/features/practice/presentation/screens/session_result_screen.dart
import 'package:flutter/material.dart';
import '../../domain/entities/exercise_result.dart';

class SessionResultScreen extends StatelessWidget {
  const SessionResultScreen({super.key, required this.result});
  final SessionResult result;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Result — coming soon')));
}
```

## Step 4: Replace app_router.dart

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_bank_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_detail_screen.dart';
import '../../features/practice/presentation/screens/practice_home_screen.dart';
import '../../features/practice/presentation/screens/practice_session_screen.dart';
import '../../features/practice/presentation/screens/session_result_screen.dart';
import '../../features/practice/domain/entities/exercise_result.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LookupScreen()),
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
        GoRoute(
          path: '/practice',
          builder: (context, state) => const PracticeHomeScreen(),
          routes: [
            GoRoute(
              path: 'session',
              builder: (context, state) => PracticeSessionScreen(
                config: state.extra as SessionConfig,
              ),
              routes: [
                GoRoute(
                  path: 'result',
                  builder: (context, state) => SessionResultScreen(
                    result: state.extra as SessionResult,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
```

## Step 5: Replace app_shell.dart

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
    if (location.startsWith('/practice')) return 2;
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
            case 0: context.go('/');
            case 1: context.go('/vocab');
            case 2: context.go('/practice');
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
        ],
      ),
    );
  }
}
```

## Step 6: Verify + commit

```
flutter analyze lib/
flutter test
git add lib/core/ lib/features/practice/presentation/screens/
git commit -m "feat(plan3): add practice DI providers, /practice routes, 3rd nav tab, placeholder screens"
```
