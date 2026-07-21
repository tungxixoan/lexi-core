# Plan 10 — Task 06: ComprehensionSessionScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 10 Task 04 (provider, DI, routes wired; stub `comprehension_session_screen.dart` exists)

## Global Constraints
(see `plan10-global-constraints.md`)

## What This Task Delivers
Replace the stub `ComprehensionSessionScreen` with the real session UI: a player card showing "Lượt N/M" (+ speaker label for a conversation) with ⏮ / ▶⏸ / ⏭ / 🔁 controls (per-turn seek, not a scrub bar), followed by all 3 questions (4 radio options each) shown together, and a "Nộp bài" button enabled only once all 3 are answered. On submission, builds a `ComprehensionSessionResult` and navigates to the result route.

## Files
- Modify: `lib/features/listening/presentation/screens/comprehension_session_screen.dart`
- Create: `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`

## Interfaces
- Consumes:
  - `listeningComprehensionNotifierProvider` — session state + `.playCurrentTurn()`, `.stopPlayback()`, `.previousTurn()`, `.nextTurn()`, `.replayFromStart()`, `.selectAnswer()`, `.submit()`
  - `ttsServiceProvider` (existing) — indirectly, via the notifier's playback methods
- Produces: fully functional `ComprehensionSessionScreen`; navigates to `/listening/comprehension/session/result` with a `ComprehensionSessionResult` as `extra` when submitted

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/presentation/providers/listening_comprehension_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/comprehension_session_screen.dart';
import 'package:lexi_core/services/tts_service.dart';

class _FakeTtsService implements TtsService {
  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0}) async {}
  @override
  Future<void> stop() async {}
}

final _testPassage = ListeningPassage(
  id: 'p1',
  kind: ListeningKind.conversation,
  turns: const [
    ListeningTurn(speaker: 'A', text: 'Can I help you?'),
    ListeningTurn(speaker: 'B', text: 'I am looking for a jacket.'),
    ListeningTurn(speaker: 'A', text: 'This way, please.'),
  ],
  questions: const [
    ListeningQuestion(question: 'Q1?', options: ['a', 'b', 'c', 'd'], correctIndex: 0),
    ListeningQuestion(question: 'Q2?', options: ['a', 'b', 'c', 'd'], correctIndex: 1),
    ListeningQuestion(question: 'Q3?', options: ['a', 'b', 'c', 'd'], correctIndex: 2),
  ],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

ListeningSessionState _session({
  int currentTurnIndex = 0,
  bool isSpeaking = false,
  List<int?>? selectedAnswers,
  bool isSubmitted = false,
}) =>
    ListeningSessionState(
      passage: _testPassage,
      currentTurnIndex: currentTurnIndex,
      isSpeaking: isSpeaking,
      playToken: 0,
      selectedAnswers: selectedAnswers ?? [null, null, null],
      isSubmitted: isSubmitted,
    );

class _FakeListeningNotifier extends ListeningComprehensionNotifier {
  _FakeListeningNotifier(this._initial);
  final ListeningSessionState _initial;
  @override
  AsyncValue<ListeningSessionState?> build() => AsyncData(_initial);
}

ComprehensionSessionResult? capturedResult;

Widget _buildSession(ListeningSessionState initial) {
  capturedResult = null;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ComprehensionSessionScreen(),
      ),
      GoRoute(
        path: '/listening/comprehension/session/result',
        builder: (ctx, state) {
          capturedResult = state.extra as ComprehensionSessionResult?;
          return const Scaffold(body: Text('Result screen'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      listeningComprehensionNotifierProvider
          .overrideWith(() => _FakeListeningNotifier(initial)),
      ttsServiceProvider.overrideWithValue(_FakeTtsService()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the turn indicator for the current turn', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lượt 1/3'), findsOneWidget);
  });

  testWidgets('shows all 3 questions with 4 options each', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    expect(find.text('Q1?'), findsOneWidget);
    expect(find.text('Q2?'), findsOneWidget);
    expect(find.text('Q3?'), findsOneWidget);
    expect(find.byType(RadioListTile<int>), findsNWidgets(12)); // 3 questions x 4 options
  });

  testWidgets('Nộp bài is disabled until all 3 questions are answered', (tester) async {
    await tester.pumpWidget(_buildSession(_session(selectedAnswers: [0, 1, null])));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all 3 are answered and navigates with the right result',
      (tester) async {
    await tester.pumpWidget(_buildSession(_session(selectedAnswers: [0, 0, 2])));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();

    expect(find.text('Result screen'), findsOneWidget);
    expect(capturedResult, isNotNull);
    expect(capturedResult!.passage, same(_testPassage));
    expect(capturedResult!.selectedAnswers, [0, 0, 2]);
    expect(capturedResult!.correctCount, 2); // correctIndex 0,1,2 vs selected 0,0,2
  });

  testWidgets('⏮ is disabled on the first turn, ⏭ advances the indicator', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    final prevButton = tester.widget<IconButton>(find.byIcon(Icons.skip_previous));
    expect(prevButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lượt 2/3'), findsOneWidget);
  });

  testWidgets('⏭ is disabled on the last turn', (tester) async {
    await tester.pumpWidget(_buildSession(_session(currentTurnIndex: 2)));
    await tester.pumpAndSettle();
    final nextButton = tester.widget<IconButton>(find.byIcon(Icons.skip_next));
    expect(nextButton.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/comprehension_session_screen_test.dart
```

Expected: FAIL — stub screen shows "Session — coming soon" text, not the real UI.

- [ ] **Step 3: Replace comprehension_session_screen.dart**

Replace `lib/features/listening/presentation/screens/comprehension_session_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/listening_passage.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionSessionScreen extends ConsumerWidget {
  const ComprehensionSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<ListeningSessionState?>>(
      listeningComprehensionNotifierProvider,
      (prev, next) {
        final session = next.valueOrNull;
        if (session == null) return;

        if (session.isSubmitted) {
          final result = ComprehensionSessionResult(
            passage: session.passage,
            selectedAnswers: session.selectedAnswers,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/listening/comprehension/session/result', extra: result);
            }
          });
        }
      },
    );

    final sessionAsync = ref.watch(listeningComprehensionNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/listening/comprehension');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        // Safety guard: navigation to the result route is already scheduled
        // via ref.listen above once isSubmitted flips to true.
        if (session.isSubmitted) {
          return const Scaffold(body: SizedBox.shrink());
        }
        return _SessionScaffold(session: session);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({required this.session});
  final ListeningSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(listeningComprehensionNotifierProvider.notifier);
    final turn = session.currentTurn;
    final isFirstTurn = session.currentTurnIndex == 0;
    final isLastTurn = session.currentTurnIndex == session.passage.turns.length - 1;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nghe hiểu'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Lượt ${session.currentTurnIndex + 1}/${session.passage.turns.length}'
                      '${turn.speaker != null ? ' — Người nói ${turn.speaker}' : ''}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          onPressed: isFirstTurn ? null : notifier.previousTurn,
                        ),
                        IconButton(
                          iconSize: 40,
                          icon: Icon(
                            session.isSpeaking ? Icons.stop_circle : Icons.play_circle,
                          ),
                          onPressed: session.isSpeaking
                              ? notifier.stopPlayback
                              : notifier.playCurrentTurn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: isLastTurn ? null : notifier.nextTurn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay),
                          onPressed: notifier.replayFromStart,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: session.passage.questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) => _QuestionCard(
                  index: i,
                  question: session.passage.questions[i],
                  selected: session.selectedAnswers[i],
                  onSelected: (optionIndex) => notifier.selectAnswer(i, optionIndex),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: session.canSubmit ? notifier.submit : null,
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int index;
  final ListeningQuestion question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${index + 1}. ${question.question}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...question.options.asMap().entries.map(
                  (entry) => RadioListTile<int>(
                    value: entry.key,
                    groupValue: selected,
                    title: Text(entry.value),
                    dense: true,
                    onChanged: (v) {
                      if (v != null) onSelected(v);
                    },
                  ),
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
flutter test test/features/listening/presentation/screens/comprehension_session_screen_test.dart
```

Expected: all 6 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/listening/presentation/screens/comprehension_session_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/listening/presentation/screens/comprehension_session_screen.dart \
        test/features/listening/presentation/screens/comprehension_session_screen_test.dart
git commit -m "feat(plan10): implement ComprehensionSessionScreen with per-turn player + questions"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
