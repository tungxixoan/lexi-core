# Plan 7 — Task 03: Provider + DI + Router + AppShell Reading Tab

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 7 Task 02 (`GenerateReadingPassageUseCase` defined); Plan 6 Task 03 (`showReadingPracticeOnMobile` in settings); Plan 6 Task 04 (`AppShell` with `_Dest` + `_destinations()` method)

## Global Constraints
(see `plan7-global-constraints.md`)

## What This Task Delivers
`ReadingPracticeNotifier` — a Riverpod `AsyncNotifier` that manages the full reading session lifecycle (generate → session state → complete). DI wiring in `app_providers.dart`. New `/reading` routes in `app_router.dart`. Reading tab in `AppShell` conditionally shown based on `kIsWeb || settings.showReadingPracticeOnMobile`.

## Files
- Create: `lib/features/reading/presentation/providers/reading_practice_provider.dart`
- Create: `lib/features/reading/presentation/providers/reading_practice_provider.g.dart` (generated)
- Modify: `lib/core/di/app_providers.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/widgets/app_shell.dart`

## Interfaces
- Consumes: `GenerateReadingPassageUseCase` from Task 02; `VocabBankNotifier` from existing code; `UserSettingsNotifier` from existing code
- Produces:
  - `SentenceResult({required String target, required String typed, required int correctChars, required int totalChars, required int durationMs})` — with `accuracy` getter
  - `ReadingSessionState({required ReadingPassage passage, required int currentSentenceIndex, required String typedText, required List<SentenceResult> completedSentences, required DateTime sessionStartedAt, required DateTime sentenceStartedAt, required bool isComplete})` — with `currentSentence` getter + `copyWith`
  - `ReadingSessionResult({required ReadingPassage passage, required List<SentenceResult> sentenceResults, required Duration totalDuration})` — with `overallAccuracy` and `wpm` getters
  - `readingPracticeNotifierProvider` — `AsyncNotifier<ReadingSessionState?>`
  - `ReadingPracticeNotifier.generate({required List<VocabRecord> words, required CEFRLevel level, required AppContext context, required Language targetLanguage})` — async, sets state to AsyncLoading then AsyncData
  - `ReadingPracticeNotifier.updateTypedText(String text)` — auto-advances when typed == target
  - `ReadingPracticeNotifier.reset()` — returns state to `AsyncData(null)`

## Steps

- [ ] **Step 1: Create reading_practice_provider.dart**

Create `lib/features/reading/presentation/providers/reading_practice_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/reading_passage.dart';

part 'reading_practice_provider.g.dart';

final class SentenceResult {
  const SentenceResult({
    required this.target,
    required this.typed,
    required this.correctChars,
    required this.totalChars,
    required this.durationMs,
  });

  final String target;
  final String typed;
  final int correctChars;
  final int totalChars;
  final int durationMs;

  double get accuracy => totalChars == 0 ? 1.0 : correctChars / totalChars;
}

final class ReadingSessionResult {
  const ReadingSessionResult({
    required this.passage,
    required this.sentenceResults,
    required this.totalDuration,
  });

  final ReadingPassage passage;
  final List<SentenceResult> sentenceResults;
  final Duration totalDuration;

  double get overallAccuracy {
    if (sentenceResults.isEmpty) return 1.0;
    final totalCorrect =
        sentenceResults.fold(0, (s, r) => s + r.correctChars);
    final totalChars = sentenceResults.fold(0, (s, r) => s + r.totalChars);
    return totalChars == 0 ? 1.0 : totalCorrect / totalChars;
  }

  double get wpm {
    final totalTyped =
        sentenceResults.fold(0, (s, r) => s + r.typed.length);
    final minutes = totalDuration.inSeconds / 60.0;
    if (minutes == 0) return 0;
    return (totalTyped / 5.0) / minutes;
  }
}

final class ReadingSessionState {
  const ReadingSessionState({
    required this.passage,
    required this.currentSentenceIndex,
    required this.typedText,
    required this.completedSentences,
    required this.sessionStartedAt,
    required this.sentenceStartedAt,
    required this.isComplete,
  });

  final ReadingPassage passage;
  final int currentSentenceIndex;
  final String typedText;
  final List<SentenceResult> completedSentences;
  final DateTime sessionStartedAt;
  final DateTime sentenceStartedAt;
  final bool isComplete;

  BilingualSentence get currentSentence =>
      passage.sentences[currentSentenceIndex];

  ReadingSessionState copyWith({
    int? currentSentenceIndex,
    String? typedText,
    List<SentenceResult>? completedSentences,
    DateTime? sentenceStartedAt,
    bool? isComplete,
  }) =>
      ReadingSessionState(
        passage: passage,
        currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
        typedText: typedText ?? this.typedText,
        completedSentences: completedSentences ?? this.completedSentences,
        sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
        sentenceStartedAt: sentenceStartedAt ?? this.sentenceStartedAt,
        isComplete: isComplete ?? this.isComplete,
      );
}

@riverpod
class ReadingPracticeNotifier extends _$ReadingPracticeNotifier {
  @override
  AsyncValue<ReadingSessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final passage = await ref
          .read(generateReadingPassageUseCaseProvider)
          .execute(
            words: words,
            level: level,
            context: context,
            targetLanguage: targetLanguage,
          );
      final now = DateTime.now();
      return ReadingSessionState(
        passage: passage,
        currentSentenceIndex: 0,
        typedText: '',
        completedSentences: const [],
        sessionStartedAt: now,
        sentenceStartedAt: now,
        isComplete: false,
      );
    });
  }

  void updateTypedText(String text) {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    if (text == current.currentSentence.target) {
      _advance(current, text);
    } else {
      state = AsyncData(current.copyWith(typedText: text));
    }
  }

  void _advance(ReadingSessionState current, String typed) {
    final target = current.currentSentence.target;
    int correctChars = 0;
    for (int i = 0; i < typed.length && i < target.length; i++) {
      if (typed[i] == target[i]) correctChars++;
    }
    final result = SentenceResult(
      target: target,
      typed: typed,
      correctChars: correctChars,
      totalChars: target.length,
      durationMs: DateTime.now()
          .difference(current.sentenceStartedAt)
          .inMilliseconds,
    );
    final nextIndex = current.currentSentenceIndex + 1;
    final isComplete = nextIndex >= current.passage.sentences.length;
    final now = DateTime.now();
    state = AsyncData(current.copyWith(
      currentSentenceIndex: nextIndex,
      typedText: '',
      completedSentences: [...current.completedSentences, result],
      sentenceStartedAt: now,
      isComplete: isComplete,
    ));
  }

  void reset() => state = const AsyncData(null);
}
```

- [ ] **Step 2: Generate Riverpod code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `reading_practice_provider.g.dart` created.

- [ ] **Step 3: Add DI providers to app_providers.dart**

In `lib/core/di/app_providers.dart`, add at the end of the file (before the closing):

```dart
// --- Reading DI (Plan 7) ---
import '../../features/reading/data/sources/reading_passage_source.dart';
import '../../features/reading/domain/use_cases/generate_reading_passage_use_case.dart';
```

Add these import lines at the top (in the imports section), then add these providers:

```dart
@riverpod
ReadingPassageSource readingPassageSource(ReadingPassageSourceRef ref) {
  final apiKey = ref.watch(
    userSettingsNotifierProvider.select((s) => s.geminiApiKey),
  );
  return ReadingPassageSource(apiKey: apiKey);
}

@riverpod
GenerateReadingPassageUseCase generateReadingPassageUseCase(
        GenerateReadingPassageUseCaseRef ref) =>
    GenerateReadingPassageUseCase(ref.watch(readingPassageSourceProvider));
```

After editing, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Add reading routes to app_router.dart**

In `lib/core/router/app_router.dart`, add the imports:
```dart
import '../../features/reading/presentation/screens/reading_home_screen.dart';
import '../../features/reading/presentation/screens/reading_session_screen.dart';
import '../../features/reading/presentation/screens/reading_result_screen.dart';
import '../../features/reading/presentation/providers/reading_practice_provider.dart';
```

Then add the `/reading` route inside the `ShellRoute.routes` list, before the `/settings` route:

```dart
GoRoute(
  path: '/reading',
  builder: (context, state) => const ReadingHomeScreen(),
  routes: [
    GoRoute(
      path: 'session',
      builder: (context, state) => const ReadingSessionScreen(),
      routes: [
        GoRoute(
          path: 'result',
          builder: (context, state) => ReadingResultScreen(
            result: state.extra as ReadingSessionResult,
          ),
        ),
      ],
    ),
  ],
),
```

The full updated `ShellRoute.routes` list in order:
```
'/'        → LookupScreen
'/vocab'   → VocabBankScreen (with nested ':id')
'/practice'→ PracticeHomeScreen (with nested 'progress', 'session', 'session/result')
'/reading' → ReadingHomeScreen (with nested 'session', 'session/result')
'/settings'→ SettingsScreen
```

- [ ] **Step 5: Update AppShell to add reading tab**

Replace `lib/core/widgets/app_shell.dart` with:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/practice/presentation/providers/notification_notifier.dart';
import '../../features/dictionary/presentation/providers/user_settings_provider.dart';

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

  List<_Dest> _destinations(bool showReading) => [
        const _Dest(
          path: '/',
          icon: Icons.search_outlined,
          selectedIcon: Icons.search,
          label: 'Dictionary',
        ),
        const _Dest(
          path: '/vocab',
          icon: Icons.library_books_outlined,
          selectedIcon: Icons.library_books,
          label: 'Vocab Bank',
        ),
        if (showReading)
          const _Dest(
            path: '/reading',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book,
            label: 'Luyện đọc & gõ',
          ),
        const _Dest(
          path: '/practice',
          icon: Icons.school_outlined,
          selectedIcon: Icons.school,
          label: 'Luyện tập',
        ),
        const _Dest(
          path: '/settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: 'Cài đặt',
        ),
      ];

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
    final showReading = kIsWeb ||
        ref.watch(
          userSettingsNotifierProvider
              .select((s) => s.showReadingPracticeOnMobile),
        );
    final dests = _destinations(showReading);
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

- [ ] **Step 6: Create stub screen files so the router can compile**

The router imports `ReadingHomeScreen`, `ReadingSessionScreen`, `ReadingResultScreen`. Create stubs now; they will be replaced in Tasks 04–06.

Create `lib/features/reading/presentation/screens/reading_home_screen.dart`:
```dart
import 'package:flutter/material.dart';

class ReadingHomeScreen extends StatelessWidget {
  const ReadingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Luyện đọc & gõ — coming soon')));
}
```

Create `lib/features/reading/presentation/screens/reading_session_screen.dart`:
```dart
import 'package:flutter/material.dart';

class ReadingSessionScreen extends StatelessWidget {
  const ReadingSessionScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Session — coming soon')));
}
```

Create `lib/features/reading/presentation/screens/reading_result_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../providers/reading_practice_provider.dart';

class ReadingResultScreen extends StatelessWidget {
  const ReadingResultScreen({super.key, required this.result});
  final ReadingSessionResult result;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Result — coming soon')));
}
```

- [ ] **Step 7: Analyze and build**

```bash
flutter analyze lib/
dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/
```

Expected: no issues after code generation.

- [ ] **Step 8: Run tests**

```bash
flutter test
```

Expected: all existing tests pass (no regressions).

- [ ] **Step 9: Verify web build**

```bash
flutter build web --release
```

Expected: builds successfully.

- [ ] **Step 10: Commit**

```bash
git add lib/features/reading/presentation/providers/reading_practice_provider.dart \
        lib/features/reading/presentation/providers/reading_practice_provider.g.dart \
        lib/features/reading/presentation/screens/reading_home_screen.dart \
        lib/features/reading/presentation/screens/reading_session_screen.dart \
        lib/features/reading/presentation/screens/reading_result_screen.dart \
        lib/core/di/app_providers.dart \
        lib/core/di/app_providers.g.dart \
        lib/core/router/app_router.dart \
        lib/core/widgets/app_shell.dart
git commit -m "feat(plan7): wire ReadingPracticeNotifier, DI, routes, and reading tab in AppShell"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Build: flutter analyze + flutter build web results
Concerns: (if any)
