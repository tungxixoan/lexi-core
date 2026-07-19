# Plan 9 — Task 04: Provider + DI + Router + AppShell + Hub Screen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 9 Task 01 (`showListeningPracticeOnMobile`); Plan 9 Task 03 (`GenerateDictationItemUseCase`)

## Global Constraints
(see `plan9-global-constraints.md`)

## What This Task Delivers
`DictationPracticeNotifier` — a Riverpod `AsyncNotifier` managing the dictation session lifecycle (generate → play/replay → type → submit). DI wiring in `app_providers.dart`. New `/listening` routes in `app_router.dart`. A "Luyện nghe" tab in `AppShell`, visible using the same width-based rule as the (already-fixed) Reading tab. A **real** `ListeningHomeScreen` hub (two cards: "Nghe chép" enabled, "Nghe hiểu" disabled/"Sắp ra mắt" since Plan 10 builds it). **Stub** screens for `DictationHomeScreen`, `DictationSessionScreen`, `DictationResultScreen` so the router compiles — Tasks 05–07 replace them with real implementations.

## Files
- Create: `lib/features/listening/presentation/providers/dictation_practice_provider.dart`
- Create: `lib/features/listening/presentation/providers/dictation_practice_provider.g.dart` (generated)
- Create: `lib/features/listening/presentation/screens/listening_home_screen.dart`
- Create: `lib/features/listening/presentation/screens/dictation_home_screen.dart` (stub)
- Create: `lib/features/listening/presentation/screens/dictation_session_screen.dart` (stub)
- Create: `lib/features/listening/presentation/screens/dictation_result_screen.dart` (stub)
- Create: `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
- Create: `test/features/listening/presentation/screens/listening_home_screen_test.dart`
- Modify: `lib/core/di/app_providers.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Modify: `test/core/widgets/app_shell_test.dart`

## Interfaces
- Consumes: `GenerateDictationItemUseCase` from Task 03; `TtsService` (existing `ttsServiceProvider`); `VocabRecord`, `CEFRLevel`, `AppContext`, `Language`, `UserSettingsState` from existing code
- Produces:
  - `DictationSessionResult({required DictationItem item, required String typed, required int replayCount, required Duration duration})` — with `correctChars`, `totalChars`, `charAccuracy`, `finalScore`, `sm2Quality` getters
  - `DictationSessionState({required DictationItem item, required String typedText, required int replayCount, required bool hasPlayedOnce, required DateTime startedAt, required bool isComplete})` — with `copyWith`
  - `dictationPracticeNotifierProvider` — `AsyncNotifier<DictationSessionState?>`
  - `DictationPracticeNotifier.generate({required List<VocabRecord> words, required CEFRLevel level, required AppContext context, required Language targetLanguage})` — async, sets state to `AsyncLoading` then `AsyncData`
  - `DictationPracticeNotifier.play()` — async; first call sets `hasPlayedOnce = true` and does not increment `replayCount`; every subsequent call increments `replayCount`. Always calls `TtsService.speak()`.
  - `DictationPracticeNotifier.updateTypedText(String text)` — updates `typedText`, does not auto-complete
  - `DictationPracticeNotifier.submit()` — sets `isComplete = true`
  - `DictationPracticeNotifier.reset()` — returns state to `AsyncData(null)`

## Steps

- [ ] **Step 1: Write the scoring-formula unit test**

Create `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';

DictationItem _item(String target) => DictationItem(
      id: 'item-1',
      target: target,
      vietnamese: '',
      vocabIds: const ['id1', 'id2'],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026),
    );

void main() {
  group('DictationSessionResult scoring', () {
    test('charAccuracy is 1.0 for an exact match', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hello world.',
        replayCount: 0,
        duration: const Duration(seconds: 5),
      );
      expect(result.charAccuracy, 1.0);
      expect(result.finalScore, 1.0);
      expect(result.sm2Quality, 5);
    });

    test('charAccuracy counts only matching positions', () {
      // 'Hxllo world.' vs 'Hello world.' — 1 mismatch out of 12 chars.
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hxllo world.',
        replayCount: 0,
        duration: const Duration(seconds: 5),
      );
      expect(result.totalChars, 12);
      expect(result.correctChars, 11);
      expect(result.charAccuracy, closeTo(11 / 12, 0.0001));
    });

    test('finalScore subtracts 5% per replay beyond the first listen', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hello world.',
        replayCount: 2,
        duration: const Duration(seconds: 5),
      );
      expect(result.charAccuracy, 1.0);
      expect(result.finalScore, closeTo(0.90, 0.0001)); // 1.0 - 2*0.05
    });

    test('finalScore never goes below 0', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: '',
        replayCount: 100,
        duration: const Duration(seconds: 5),
      );
      expect(result.finalScore, 0.0);
    });

    test('sm2Quality maps finalScore to the 0-5 SM-2 scale', () {
      DictationSessionResult withScoreInputs(int replayCount) => DictationSessionResult(
            item: _item('Hello world.'),
            typed: 'Hello world.',
            replayCount: replayCount,
            duration: const Duration(seconds: 5),
          );

      expect(withScoreInputs(0).sm2Quality, 5); // finalScore 1.00 >= 0.95
      expect(withScoreInputs(3).sm2Quality, 4); // finalScore 0.85 >= 0.80
      expect(withScoreInputs(6).sm2Quality, 3); // finalScore 0.70 >= 0.60
      expect(withScoreInputs(9).sm2Quality, 2); // finalScore 0.55 >= 0.40
      expect(withScoreInputs(20).sm2Quality, 0); // finalScore 0.00
    });

    test('charAccuracy is 1.0 when target is empty', () {
      final result = DictationSessionResult(
        item: _item(''),
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
      );
      expect(result.charAccuracy, 1.0);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart
```

Expected: FAIL — `dictation_practice_provider.dart` doesn't exist.

- [ ] **Step 3: Create dictation_practice_provider.dart**

Create `lib/features/listening/presentation/providers/dictation_practice_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/dictation_item.dart';

part 'dictation_practice_provider.g.dart';

final class DictationSessionResult {
  const DictationSessionResult({
    required this.item,
    required this.typed,
    required this.replayCount,
    required this.duration,
  });

  final DictationItem item;
  final String typed;
  final int replayCount;
  final Duration duration;

  int get totalChars => item.target.length;

  int get correctChars {
    int correct = 0;
    final limit = typed.length < item.target.length
        ? typed.length
        : item.target.length;
    for (int i = 0; i < limit; i++) {
      if (typed[i] == item.target[i]) correct++;
    }
    return correct;
  }

  double get charAccuracy => totalChars == 0 ? 1.0 : correctChars / totalChars;

  double get finalScore =>
      (charAccuracy - 0.05 * replayCount).clamp(0.0, 1.0);

  int get sm2Quality {
    final score = finalScore;
    if (score >= 0.95) return 5;
    if (score >= 0.80) return 4;
    if (score >= 0.60) return 3;
    if (score >= 0.40) return 2;
    return 0;
  }
}

final class DictationSessionState {
  const DictationSessionState({
    required this.item,
    required this.typedText,
    required this.replayCount,
    required this.hasPlayedOnce,
    required this.startedAt,
    required this.isComplete,
  });

  final DictationItem item;
  final String typedText;
  final int replayCount;
  final bool hasPlayedOnce;
  final DateTime startedAt;
  final bool isComplete;

  DictationSessionState copyWith({
    String? typedText,
    int? replayCount,
    bool? hasPlayedOnce,
    bool? isComplete,
  }) =>
      DictationSessionState(
        item: item,
        typedText: typedText ?? this.typedText,
        replayCount: replayCount ?? this.replayCount,
        hasPlayedOnce: hasPlayedOnce ?? this.hasPlayedOnce,
        startedAt: startedAt,
        isComplete: isComplete ?? this.isComplete,
      );
}

@riverpod
class DictationPracticeNotifier extends _$DictationPracticeNotifier {
  @override
  AsyncValue<DictationSessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final item = await ref.read(generateDictationItemUseCaseProvider).execute(
            words: words,
            level: level,
            context: context,
            targetLanguage: targetLanguage,
          );
      return DictationSessionState(
        item: item,
        typedText: '',
        replayCount: 0,
        hasPlayedOnce: false,
        startedAt: DateTime.now(),
        isComplete: false,
      );
    });
  }

  Future<void> play() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.hasPlayedOnce
          ? current.copyWith(replayCount: current.replayCount + 1)
          : current.copyWith(hasPlayedOnce: true),
    );
    await ref
        .read(ttsServiceProvider)
        .speak(current.item.target, current.item.targetLanguage);
  }

  void updateTypedText(String text) {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    state = AsyncData(current.copyWith(typedText: text));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    state = AsyncData(current.copyWith(isComplete: true));
  }

  void reset() => state = const AsyncData(null);
}
```

- [ ] **Step 4: Generate Riverpod code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `dictation_practice_provider.g.dart` created.

- [ ] **Step 5: Run the scoring test — should pass now**

```bash
flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart
```

Expected: all 6 tests pass.

- [ ] **Step 6: Add DI providers to app_providers.dart**

In `lib/core/di/app_providers.dart`, add these imports after the existing `// --- Reading DI (Plan 7) ---` block:

```dart
// --- Listening DI (Plan 9) ---
import '../../features/listening/data/sources/dictation_source.dart';
import '../../features/listening/domain/use_cases/generate_dictation_item_use_case.dart';
```

Then add these providers at the end of the file:

```dart
@riverpod
DictationSource dictationSource(DictationSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return DictationSource(settings);
}

@riverpod
GenerateDictationItemUseCase generateDictationItemUseCase(
        GenerateDictationItemUseCaseRef ref) =>
    GenerateDictationItemUseCase(ref.watch(dictationSourceProvider));
```

After editing, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 7: Create the real ListeningHomeScreen hub**

Create `lib/features/listening/presentation/screens/listening_home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ListeningHomeScreen extends StatelessWidget {
  const ListeningHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện nghe'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Nghe chép'),
              subtitle: const Text(
                'Nghe một câu và gõ lại chính xác những gì bạn nghe được.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/listening/dictation'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              enabled: false,
              leading: Icon(
                Icons.quiz_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              title: const Text('Nghe hiểu'),
              subtitle: const Text(
                'Nghe hội thoại/bài nói và trả lời câu hỏi trắc nghiệm kiểu TOEIC.',
              ),
              trailing: Chip(label: const Text('Sắp ra mắt')),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Write the hub widget test**

Create `test/features/listening/presentation/screens/listening_home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/listening/presentation/screens/listening_home_screen.dart';

Widget _buildHub() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ListeningHomeScreen(),
      ),
      GoRoute(
        path: '/listening/dictation',
        builder: (ctx, state) => const Scaffold(body: Text('Dictation home')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows both Nghe chép and Nghe hiểu cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Nghe chép'), findsOneWidget);
    expect(find.text('Nghe hiểu'), findsOneWidget);
    expect(find.text('Sắp ra mắt'), findsOneWidget);
  });

  testWidgets('tapping Nghe chép navigates to dictation home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghe chép'));
    await tester.pumpAndSettle();
    expect(find.text('Dictation home'), findsOneWidget);
  });
}
```

- [ ] **Step 9: Create stub screens so the router compiles**

Create `lib/features/listening/presentation/screens/dictation_home_screen.dart`:

```dart
import 'package:flutter/material.dart';

class DictationHomeScreen extends StatelessWidget {
  const DictationHomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Nghe chép — coming soon')));
}
```

Create `lib/features/listening/presentation/screens/dictation_session_screen.dart`:

```dart
import 'package:flutter/material.dart';

class DictationSessionScreen extends StatelessWidget {
  const DictationSessionScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Session — coming soon')));
}
```

Create `lib/features/listening/presentation/screens/dictation_result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../providers/dictation_practice_provider.dart';

class DictationResultScreen extends StatelessWidget {
  const DictationResultScreen({super.key, required this.result});
  final DictationSessionResult result;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Result — coming soon')));
}
```

- [ ] **Step 10: Add /listening routes to app_router.dart**

In `lib/core/router/app_router.dart`, add these imports after the existing reading imports:

```dart
import '../../features/listening/presentation/screens/listening_home_screen.dart';
import '../../features/listening/presentation/screens/dictation_home_screen.dart';
import '../../features/listening/presentation/screens/dictation_session_screen.dart';
import '../../features/listening/presentation/screens/dictation_result_screen.dart';
import '../../features/listening/presentation/providers/dictation_practice_provider.dart';
```

Then add the `/listening` route inside `ShellRoute.routes`, between the `/reading` route and the `/settings` route:

```dart
        GoRoute(
          path: '/listening',
          builder: (context, state) => const ListeningHomeScreen(),
          routes: [
            GoRoute(
              path: 'dictation',
              builder: (context, state) => const DictationHomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const DictationSessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! DictationSessionResult) {
                          return '/listening/dictation';
                        }
                        return null;
                      },
                      builder: (context, state) => DictationResultScreen(
                        result: state.extra as DictationSessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
```

- [ ] **Step 11: Add the Listening tab to AppShell**

In `lib/core/widgets/app_shell.dart`, update `_destinations` to take a second bool parameter and add the new destination right after the Reading one:

```dart
  List<_Dest> _destinations(bool showReading, bool showListening) => [
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
            label: 'Đọc',
          ),
        if (showListening)
          const _Dest(
            path: '/listening',
            icon: Icons.headphones_outlined,
            selectedIcon: Icons.headphones,
            label: 'Luyện nghe',
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
```

Then update `build()` — it currently reads:

```dart
  @override
  Widget build(BuildContext context) {
    final showReadingOnMobile = ref.watch(
      userSettingsNotifierProvider.select((s) => s.showReadingPracticeOnMobile),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // "Mobile" means a phone-sized viewport, not the web/native platform —
        // a phone browser and a narrow Chrome DevTools window are both
        // kIsWeb == true, so that flag can't distinguish them from desktop.
        final showReading = constraints.maxWidth >= 600 || showReadingOnMobile;
        final dests = _destinations(showReading);
        final selectedIndex = _selectedIndex(context, dests);
```

Replace with:

```dart
  @override
  Widget build(BuildContext context) {
    final showReadingOnMobile = ref.watch(
      userSettingsNotifierProvider.select((s) => s.showReadingPracticeOnMobile),
    );
    final showListeningOnMobile = ref.watch(
      userSettingsNotifierProvider.select((s) => s.showListeningPracticeOnMobile),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // "Mobile" means a phone-sized viewport, not the web/native platform —
        // a phone browser and a narrow Chrome DevTools window are both
        // kIsWeb == true, so that flag can't distinguish them from desktop.
        final showReading = constraints.maxWidth >= 600 || showReadingOnMobile;
        final showListening = constraints.maxWidth >= 600 || showListeningOnMobile;
        final dests = _destinations(showReading, showListening);
        final selectedIndex = _selectedIndex(context, dests);
```

(The rest of the file — the `if (constraints.maxWidth >= 600)` branch and the `NavigationBar` branch below it — is unchanged; they already reference `dests` and `selectedIndex` by name.)

- [ ] **Step 12: Update app_shell_test.dart with Listening tab coverage**

In `test/core/widgets/app_shell_test.dart`, update `_buildShell` to accept an optional listening toggle:

```dart
Future<Widget> _buildShell({
  bool showReadingPracticeOnMobile = false,
  bool showListeningPracticeOnMobile = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (showReadingPracticeOnMobile) 'show_reading_mobile': true,
    if (showListeningPracticeOnMobile) 'show_listening_mobile': true,
  });
  final prefs = await SharedPreferences.getInstance();
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
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
```

Then add these tests at the end of `main()`, before the closing brace:

```dart
  testWidgets('hides Listening tab on narrow screen when toggle is off',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.text('Luyện nghe'), findsNothing);
  });

  testWidgets('shows Listening tab on narrow screen when toggle is on',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      await _buildShell(showListeningPracticeOnMobile: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Luyện nghe'), findsOneWidget);
  });

  testWidgets('shows Listening tab on wide screen regardless of toggle',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.text('Luyện nghe'), findsOneWidget);
  });
```

- [ ] **Step 13: Analyze and build**

```bash
flutter analyze lib/
dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/
```

Expected: no issues after code generation.

- [ ] **Step 14: Run full test suite**

```bash
flutter test
```

Expected: all tests pass (no regressions), including the new Listening tab and hub tests.

- [ ] **Step 15: Verify web build**

```bash
flutter build web --release
```

Expected: builds successfully.

- [ ] **Step 16: Commit**

```bash
git add lib/features/listening/presentation/providers/dictation_practice_provider.dart \
        lib/features/listening/presentation/providers/dictation_practice_provider.g.dart \
        lib/features/listening/presentation/screens/listening_home_screen.dart \
        lib/features/listening/presentation/screens/dictation_home_screen.dart \
        lib/features/listening/presentation/screens/dictation_session_screen.dart \
        lib/features/listening/presentation/screens/dictation_result_screen.dart \
        lib/core/di/app_providers.dart \
        lib/core/di/app_providers.g.dart \
        lib/core/router/app_router.dart \
        lib/core/widgets/app_shell.dart \
        test/features/listening/presentation/providers/dictation_practice_provider_test.dart \
        test/features/listening/presentation/screens/listening_home_screen_test.dart \
        test/core/widgets/app_shell_test.dart
git commit -m "feat(plan9): wire DictationPracticeNotifier, DI, routes, Listening tab, and hub screen"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Build: flutter analyze + flutter build web results
Concerns: (if any)
