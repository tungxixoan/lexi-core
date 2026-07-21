# Plan 10 — Task 07: ComprehensionResultScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 10 Task 06 (session screen navigates to `/listening/comprehension/session/result` with `ComprehensionSessionResult` extra)

## Global Constraints
(see `plan10-global-constraints.md`)

## What This Task Delivers
Replace the stub `ComprehensionResultScreen` with the full result view: score `X/3`, a per-question breakdown (correct/incorrect icon, the correct option and the user's selected option both highlighted), the full transcript (all turns, with speaker labels for a conversation), and two action buttons — "Bài khác" (regenerate) and "Về trang chính" (go home). **No SM-2 update anywhere in this screen** — there is no specific vocab word to attribute a conversation-level score to (unlike Dictation's result screen).

## Files
- Modify: `lib/features/listening/presentation/screens/comprehension_result_screen.dart`
- Create: `test/features/listening/presentation/screens/comprehension_result_screen_test.dart`

## Interfaces
- Consumes:
  - `ComprehensionSessionResult` (passed via `state.extra`) — `passage`, `selectedAnswers`, `correctCount` from Task 04
  - `listeningComprehensionNotifierProvider.notifier.reset()` — to clear state before navigating home or regenerating

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/listening/presentation/screens/comprehension_result_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/presentation/providers/listening_comprehension_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/comprehension_result_screen.dart';

final _testPassage = ListeningPassage(
  id: 'p1',
  kind: ListeningKind.conversation,
  turns: const [
    ListeningTurn(speaker: 'A', text: 'Can I help you?'),
    ListeningTurn(speaker: 'B', text: 'I am looking for a jacket.'),
  ],
  questions: const [
    ListeningQuestion(question: 'Where are they?', options: ['Store', 'Airport', 'Home', 'School'], correctIndex: 0),
    ListeningQuestion(question: 'What do they want?', options: ['Shoes', 'A jacket', 'A book', 'A ticket'], correctIndex: 1),
    ListeningQuestion(question: 'Who is speaking first?', options: ['A', 'B', 'Both', 'Neither'], correctIndex: 0),
  ],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

// selectedAnswers: [0 (correct), 0 (wrong, correct is 1), 0 (correct)] -> 2/3
final _testResult = ComprehensionSessionResult(
  passage: _testPassage,
  selectedAnswers: const [0, 0, 0],
);

Widget _buildResult() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ComprehensionResultScreen(result: _testResult),
      ),
      GoRoute(
        path: '/listening/comprehension',
        builder: (ctx, state) => const Scaffold(body: Text('Comprehension home')),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('shows the score as correctCount/total', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('shows all 3 question texts and the transcript turns', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('Where are they?'), findsOneWidget);
    expect(find.textContaining('What do they want?'), findsOneWidget);
    expect(find.textContaining('Who is speaking first?'), findsOneWidget);
    expect(find.textContaining('Can I help you?'), findsOneWidget);
    expect(find.textContaining('I am looking for a jacket.'), findsOneWidget);
  });

  testWidgets('shows correct/incorrect icons matching correctCount', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.cancel), findsNWidgets(1));
  });

  testWidgets('shows Bài khác and Về trang chính buttons', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Bài khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/comprehension_result_screen_test.dart
```

Expected: FAIL — stub screen shows "Result — coming soon" text.

- [ ] **Step 3: Replace comprehension_result_screen.dart**

Replace `lib/features/listening/presentation/screens/comprehension_result_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/listening_passage.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionResultScreen extends ConsumerWidget {
  const ComprehensionResultScreen({super.key, required this.result});
  final ComprehensionSessionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = result.passage.questions.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '${result.correctCount}/$total',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: result.correctCount == total
                      ? Colors.green.shade700
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ...result.passage.questions.asMap().entries.map((entry) {
                    final i = entry.key;
                    return _QuestionBreakdown(
                      index: i,
                      question: entry.value,
                      selected: result.selectedAnswers[i],
                    );
                  }),
                  const SizedBox(height: 16),
                  Text('Bản ghi âm', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...result.passage.turns.map(
                    (t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        t.speaker != null ? '${t.speaker}: ${t.text}' : t.text,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _regenerate(context, ref),
              child: const Text('Bài khác'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _goHome(context, ref),
              child: const Text('Về trang chính'),
            ),
          ],
        ),
      ),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(listeningComprehensionNotifierProvider.notifier).reset();
    context.go('/listening/comprehension');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(listeningComprehensionNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({
    required this.index,
    required this.question,
    required this.selected,
  });

  final int index;
  final ListeningQuestion question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = selected == question.correctIndex;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${index + 1}. ${question.question}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...question.options.asMap().entries.map((entry) {
              final i = entry.key;
              final isCorrectOption = i == question.correctIndex;
              final isSelectedOption = i == selected;
              Color? color;
              if (isCorrectOption) {
                color = Colors.green;
              } else if (isSelectedOption) {
                color = theme.colorScheme.error;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  entry.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight:
                        (isCorrectOption || isSelectedOption) ? FontWeight.bold : null,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/listening/presentation/screens/comprehension_result_screen_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/listening/
```

Expected: no issues.

- [ ] **Step 7: Verify final web build**

```bash
flutter build web --release
```

Expected: builds successfully.

- [ ] **Step 8: Verify mobile debug build**

```bash
flutter build apk --debug
```

Expected: builds successfully.

- [ ] **Step 9: Commit**

```bash
git add lib/features/listening/presentation/screens/comprehension_result_screen.dart \
        test/features/listening/presentation/screens/comprehension_result_screen_test.dart
git commit -m "feat(plan10): implement ComprehensionResultScreen with score + breakdown + transcript"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Build: web + apk results
Concerns: (if any)
