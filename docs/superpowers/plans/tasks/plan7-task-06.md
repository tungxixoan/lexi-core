# Plan 7 — Task 06: ReadingResultScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 7 Task 05 (session screen navigates to `/reading/session/result` with `ReadingSessionResult` extra)

## Global Constraints
(see `plan7-global-constraints.md`)

## What This Task Delivers
Replace the stub `ReadingResultScreen` with the full result view: accuracy %, WPM, elapsed time, list of vocab words used in the passage (headword + meaning), and two action buttons — "Sinh bài mới" (regenerate) and "Về trang chính" (go home).

## Files
- Modify: `lib/features/reading/presentation/screens/reading_result_screen.dart`

## Interfaces
- Consumes:
  - `ReadingSessionResult` (passed via `state.extra`)
  - `vocabBankProvider` — to look up headwords + meanings for the vocab list
  - `readingPracticeNotifierProvider.notifier.reset()` — to clear state before navigating home or re-generating

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/reading/presentation/screens/reading_result_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/reading_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_result_screen.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';

final _testResult = ReadingSessionResult(
  passage: ReadingPassage(
    id: 'p1',
    sentences: const [
      BilingualSentence(
        target: 'Hello world.',
        vietnamese: 'Xin chào thế giới.',
        vocabIds: [],
      ),
    ],
    vocabIds: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  ),
  sentenceResults: const [
    SentenceResult(
      target: 'Hello world.',
      typed: 'Hello world.',
      correctChars: 12,
      totalChars: 12,
      durationMs: 5000,
    ),
  ],
  totalDuration: const Duration(seconds: 5),
);

Widget _buildResult() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ReadingResultScreen(result: _testResult),
      ),
      GoRoute(
        path: '/reading',
        builder: (ctx, state) =>
            const Scaffold(body: Text('Home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      vocabBankProvider.overrideWith((_) => const []),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows accuracy percentage', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('100'), findsWidgets); // 100% accuracy
  });

  testWidgets('shows regenerate and home buttons', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Sinh bài mới'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/reading/presentation/screens/reading_result_screen_test.dart
```

Expected: FAIL — stub screen doesn't render accuracy or buttons.

- [ ] **Step 3: Replace reading_result_screen.dart**

Replace `lib/features/reading/presentation/screens/reading_result_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../providers/reading_practice_provider.dart';

class ReadingResultScreen extends ConsumerWidget {
  const ReadingResultScreen({super.key, required this.result});
  final ReadingSessionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabRecords = ref.watch(vocabBankProvider);
    final theme = Theme.of(context);

    final accuracyPct = (result.overallAccuracy * 100).toStringAsFixed(1);
    final wpm = result.wpm.toStringAsFixed(0);
    final elapsed = _formatDuration(result.totalDuration);

    final usedRecords = result.passage.vocabIds
        .map((id) => vocabRecords.where((r) => r.id == id).firstOrNull)
        .whereType<VocabRecord>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Độ chính xác', value: '$accuracyPct%'),
                _StatCard(label: 'Tốc độ', value: '$wpm WPM'),
                _StatCard(label: 'Thời gian', value: elapsed),
              ],
            ),
            const SizedBox(height: 24),
            if (usedRecords.isNotEmpty) ...[
              Text(
                'Từ vựng đã luyện',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: usedRecords.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final record = usedRecords[i];
                    return ListTile(
                      title: Text(record.headword),
                      subtitle: Text(
                        record.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const Spacer(),
            // Action buttons
            FilledButton(
              onPressed: () => _regenerate(context, ref),
              child: const Text('Sinh bài mới'),
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
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/reading');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
```

- [ ] **Step 4: Run widget test**

```bash
flutter test test/features/reading/presentation/screens/reading_result_screen_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/reading/
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
git add lib/features/reading/presentation/screens/reading_result_screen.dart \
        test/features/reading/presentation/screens/reading_result_screen_test.dart
git commit -m "feat(plan7): implement ReadingResultScreen with accuracy, WPM, vocab list"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output (pass/fail counts)
Build: web + apk results
Concerns: (if any)
