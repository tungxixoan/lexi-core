# Plan 9 — Task 07: DictationResultScreen + SM-2 Update

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 9 Task 06 (session screen navigates to `/listening/dictation/session/result` with `DictationSessionResult` extra)

## Global Constraints
(see `plan9-global-constraints.md`)

## What This Task Delivers
Replace the stub `DictationResultScreen` with the full result view: final score %, replay count, elapsed time, a colored character diff (typed vs. the now-revealed target sentence), the Vietnamese translation, and two action buttons — "Câu khác" (regenerate) and "Về trang chính" (go home). On `initState`, applies the SM-2 update to every vocab word used in the sentence — mirroring the exact pattern `SessionResultScreen._updateSm2()` already uses for Practice sessions, which is the one place in this codebase SM-2 updates are actually wired up.

## Files
- Modify: `lib/features/listening/presentation/screens/dictation_result_screen.dart`
- Create: `test/features/listening/presentation/screens/dictation_result_screen_test.dart`

## Interfaces
- Consumes:
  - `DictationSessionResult` (passed via `state.extra`) — `charAccuracy`, `finalScore`, `sm2Quality`, `correctChars`, `totalChars` getters from Task 04
  - `computeSm2UseCaseProvider` (existing) — `ComputeSm2UseCase.compute(VocabRecord, int quality) → VocabRecord`
  - `updateVocabUseCaseProvider` (existing) — persists the updated record
  - `vocabBankProvider` (existing) — to look up the `VocabRecord`s referenced by `result.item.vocabIds`
  - `dictationPracticeNotifierProvider.notifier.reset()` — to clear state before navigating home or regenerating

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/listening/presentation/screens/dictation_result_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/dictation_result_screen.dart';

VocabRecord _record(String id) => VocabRecord(
      id: id,
      headword: id,
      inputType: InputType.word,
      ipa: '',
      meaning: 'meaning of $id',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _CapturingVocabRepository implements VocabRepository {
  _CapturingVocabRepository(this.records);
  final List<VocabRecord> records;
  final List<VocabRecord> updated = [];

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> update(VocabRecord record) async {
    updated.add(record);
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async =>
      null;

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

final _testItem = DictationItem(
  id: 'item-1',
  target: 'Hello world.',
  vietnamese: 'Xin chào thế giới.',
  vocabIds: const ['id1', 'id2'],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _perfectResult = DictationSessionResult(
  item: _testItem,
  typed: 'Hello world.',
  replayCount: 0,
  duration: const Duration(seconds: 5),
);

Widget _buildResult(
  DictationSessionResult result,
  _CapturingVocabRepository repo,
) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => DictationResultScreen(result: result),
      ),
      GoRoute(
        path: '/listening/dictation',
        builder: (ctx, state) => const Scaffold(body: Text('Dictation home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      vocabRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the final score percentage', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('100'), findsWidgets); // 100% score
  });

  testWidgets('shows the target sentence and Vietnamese translation', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hello world.'), findsWidgets);
    expect(find.text('Xin chào thế giới.'), findsOneWidget);
  });

  testWidgets('shows Câu khác and Về trang chính buttons', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.text('Câu khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets('updates SM-2 for every vocab word used in the sentence', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();

    expect(repo.updated.length, 2);
    expect(repo.updated.map((r) => r.id), containsAll(['id1', 'id2']));
    // finalScore is 1.0 -> quality 5 -> quality >= 3 branch -> repetitions 0 -> 1
    for (final r in repo.updated) {
      expect(r.sm2Repetitions, 1);
      expect(r.nextReviewAt, isNotNull);
    }
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/dictation_result_screen_test.dart
```

Expected: FAIL — stub screen shows "Result — coming soon" text, no SM-2 update happens.

- [ ] **Step 3: Replace dictation_result_screen.dart**

Replace `lib/features/listening/presentation/screens/dictation_result_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../providers/dictation_practice_provider.dart';

class DictationResultScreen extends ConsumerStatefulWidget {
  const DictationResultScreen({super.key, required this.result});
  final DictationSessionResult result;

  @override
  ConsumerState<DictationResultScreen> createState() =>
      _DictationResultScreenState();
}

class _DictationResultScreenState extends ConsumerState<DictationResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSm2());
  }

  Future<void> _updateSm2() async {
    final computeUseCase = ref.read(computeSm2UseCaseProvider);
    final updateUseCase = ref.read(updateVocabUseCaseProvider);
    final vocabRecords = ref.read(vocabBankProvider);
    final quality = widget.result.sm2Quality;

    for (final id in widget.result.item.vocabIds) {
      try {
        final record = vocabRecords.firstWhere((r) => r.id == id);
        final updated = computeUseCase.compute(record, quality);
        await updateUseCase.execute(updated);
      } catch (_) {
        // best-effort: don't crash the result screen on an SM-2 update failure
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final scorePct = (result.finalScore * 100).toStringAsFixed(0);
    final elapsed = _formatDuration(result.duration);

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Điểm', value: '$scorePct%'),
                _StatCard(label: 'Nghe lại', value: '${result.replayCount}'),
                _StatCard(label: 'Thời gian', value: elapsed),
              ],
            ),
            const SizedBox(height: 24),
            Text('Bạn đã gõ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _DiffText(
              typed: result.typed,
              target: result.item.target,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text('Câu đúng', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.item.target, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text('Nghĩa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.item.vietnamese, style: theme.textTheme.bodyLarge),
            const Spacer(),
            FilledButton(
              onPressed: () => _regenerate(context, ref),
              child: const Text('Câu khác'),
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
    ref.read(dictationPracticeNotifierProvider.notifier).reset();
    context.go('/listening/dictation');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(dictationPracticeNotifierProvider.notifier).reset();
    context.go('/');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _DiffText extends StatelessWidget {
  const _DiffText({required this.typed, required this.target, this.style});
  final String typed;
  final String target;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    for (int i = 0; i < typed.length; i++) {
      final correct = i < target.length && typed[i] == target[i];
      spans.add(TextSpan(
        text: typed[i],
        style: (style ?? const TextStyle()).copyWith(
          color: correct ? Colors.green : theme.colorScheme.error,
          backgroundColor:
              correct ? null : theme.colorScheme.error.withValues(alpha: 0.1),
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans, style: style));
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

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/listening/presentation/screens/dictation_result_screen_test.dart
```

Expected: all 4 tests pass, including the SM-2 update verification.

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
git add lib/features/listening/presentation/screens/dictation_result_screen.dart \
        test/features/listening/presentation/screens/dictation_result_screen_test.dart
git commit -m "feat(plan9): implement DictationResultScreen with diff view + SM-2 update"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Build: web + apk results
Concerns: (if any)
