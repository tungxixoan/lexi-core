# Plan 9 — Task 06: DictationSessionScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 9 Task 04 (provider, DI, routes wired; stub `dictation_session_screen.dart` exists)

## Global Constraints
(see `plan9-global-constraints.md`)

## What This Task Delivers
Replace the stub `DictationSessionScreen` with the real session UI: a Play/Replay button (label changes from "Phát" to "Nghe lại (N)" after the first tap), a plain `TextField` with **no live per-character coloring** (this is blind dictation — there's nothing visible to diff against until the user submits), and a "Nộp bài" button enabled only after the first listen and once some text has been typed. On completion, builds a `DictationSessionResult` and navigates to the result route.

## Files
- Modify: `lib/features/listening/presentation/screens/dictation_session_screen.dart`
- Create: `test/features/listening/presentation/screens/dictation_session_screen_test.dart`

## Interfaces
- Consumes:
  - `dictationPracticeNotifierProvider` — session state + `.play()`, `.updateTypedText()`, `.submit()`
  - `ttsServiceProvider` (existing) — indirectly, via `DictationPracticeNotifier.play()`
- Produces: fully functional `DictationSessionScreen`; navigates to `/listening/dictation/session/result` with a `DictationSessionResult` as `extra` when the session completes

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/listening/presentation/screens/dictation_session_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/dictation_session_screen.dart';
import 'package:lexi_core/services/tts_service.dart';

class _FakeTtsService implements TtsService {
  int speakCount = 0;

  @override
  Future<void> speak(String text, Language language) async {
    speakCount++;
  }

  @override
  Future<void> stop() async {}
}

final _testItem = DictationItem(
  id: 'item-1',
  target: 'Hello world.',
  vietnamese: 'Xin chào thế giới.',
  vocabIds: const [],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

DictationSessionState _session({
  String typedText = '',
  int replayCount = 0,
  bool hasPlayedOnce = false,
  bool isComplete = false,
}) =>
    DictationSessionState(
      item: _testItem,
      typedText: typedText,
      replayCount: replayCount,
      hasPlayedOnce: hasPlayedOnce,
      startedAt: DateTime(2026),
      isComplete: isComplete,
    );

class _FakeDictationNotifier extends DictationPracticeNotifier {
  _FakeDictationNotifier(this._initial);
  final DictationSessionState _initial;
  @override
  AsyncValue<DictationSessionState?> build() => AsyncData(_initial);
}

Widget _buildSession(DictationSessionState initial) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const DictationSessionScreen(),
      ),
      GoRoute(
        path: '/listening/dictation/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      dictationPracticeNotifierProvider
          .overrideWith(() => _FakeDictationNotifier(initial)),
      ttsServiceProvider.overrideWithValue(_FakeTtsService()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows Phát button before the first play', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    expect(find.text('Phát'), findsOneWidget);
  });

  testWidgets('shows a TextField for typing', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Nộp bài is disabled before the first play', (tester) async {
    await tester.pumpWidget(_buildSession(_session(typedText: 'Hello')));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled after playing and typing something',
      (tester) async {
    await tester.pumpWidget(
      _buildSession(_session(typedText: 'Hello', hasPlayedOnce: true)),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('tapping play changes the button label to Nghe lại (0)',
      (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phát'));
    await tester.pumpAndSettle();
    expect(find.text('Nghe lại (0)'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart
```

Expected: FAIL — stub screen shows "Session — coming soon" text, not the real UI.

- [ ] **Step 3: Replace dictation_session_screen.dart**

Replace `lib/features/listening/presentation/screens/dictation_session_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/dictation_practice_provider.dart';

class DictationSessionScreen extends ConsumerStatefulWidget {
  const DictationSessionScreen({super.key});

  @override
  ConsumerState<DictationSessionScreen> createState() =>
      _DictationSessionScreenState();
}

class _DictationSessionScreenState extends ConsumerState<DictationSessionScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DictationSessionState?>>(
      dictationPracticeNotifierProvider,
      (prev, next) {
        final session = next.valueOrNull;
        if (session == null) return;

        if (session.isComplete) {
          final result = DictationSessionResult(
            item: session.item,
            typed: session.typedText,
            replayCount: session.replayCount,
            duration: DateTime.now().difference(session.startedAt),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/listening/dictation/session/result', extra: result);
            }
          });
        }
      },
    );

    final sessionAsync = ref.watch(dictationPracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/listening/dictation');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        // Safety guard: navigation to the result route is already scheduled
        // via ref.listen above once isComplete flips to true.
        if (session.isComplete) {
          return const Scaffold(body: SizedBox.shrink());
        }
        return _SessionScaffold(session: session, ctrl: _ctrl);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({required this.session, required this.ctrl});
  final DictationSessionState session;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dictationPracticeNotifierProvider.notifier);
    final canSubmit = session.hasPlayedOnce && session.typedText.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Nghe chép'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: FilledButton.icon(
                onPressed: notifier.play,
                icon: Icon(session.hasPlayedOnce ? Icons.replay : Icons.play_arrow),
                label: Text(
                  session.hasPlayedOnce
                      ? 'Nghe lại (${session.replayCount})'
                      : 'Phát',
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: ctrl,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Gõ lại những gì bạn nghe được...',
              ),
              onChanged: notifier.updateTypedText,
            ),
            const Spacer(),
            FilledButton(
              onPressed: canSubmit ? notifier.submit : null,
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart
```

Expected: all 5 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/listening/presentation/screens/dictation_session_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/listening/presentation/screens/dictation_session_screen.dart \
        test/features/listening/presentation/screens/dictation_session_screen_test.dart
git commit -m "feat(plan9): implement DictationSessionScreen with play/replay + submit flow"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
