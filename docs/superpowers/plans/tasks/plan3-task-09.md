# Plan 3 — Task 09: SessionResultScreen + SM-2 Update

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 02 (`computeSm2UseCaseProvider`), Task 04 (placeholder + `updateVocabUseCaseProvider`), Task 08 (navigation to result)

## Global Constraints
(see `plan3-global-constraints.md`)
- SM-2 update is best-effort — catch exceptions per word, never crash the screen
- `updateVocabUseCaseProvider` — already registered in Plan 2; auto-sets `updatedAt = now`

## What This Task Delivers

Replace placeholder `SessionResultScreen` with real result UI:
- Score card: `X%` + "X / Y từ đúng"
- Per-word list with ✓ or ✗ icon + headword + meaning
- "Luyện tập lại" button → navigate back to `/practice`
- On `initState`: trigger background SM-2 updates for all results via `computeSm2UseCaseProvider` + `updateVocabUseCaseProvider`

## Files

- Modify: `lib/features/practice/presentation/screens/session_result_screen.dart`

## Implementation

```dart
// lib/features/practice/presentation/screens/session_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/exercise_result.dart';

class SessionResultScreen extends ConsumerStatefulWidget {
  const SessionResultScreen({super.key, required this.result});
  final SessionResult result;

  @override
  ConsumerState<SessionResultScreen> createState() => _SessionResultScreenState();
}

class _SessionResultScreenState extends ConsumerState<SessionResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSm2());
  }

  Future<void> _updateSm2() async {
    final computeUseCase = ref.read(computeSm2UseCaseProvider);
    final updateUseCase = ref.read(updateVocabUseCaseProvider);

    for (final result in widget.result.results) {
      final word = widget.result.words.firstWhere(
        (w) => w.id == result.vocabRecordId,
        orElse: () => throw StateError('Word not found: ${result.vocabRecordId}'),
      );
      final updated = computeUseCase.compute(word, result.quality);
      try {
        await updateUseCase.execute(updated);
      } catch (_) {
        // best-effort: don't crash result screen on SM-2 update failure
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = widget.result.correctCount;
    final total = widget.result.totalCount;
    final pct = total > 0 ? (correct / total * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '$pct%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: pct >= 70 ? Colors.green.shade700 : theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$correct / $total từ đúng', style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.result.results.length,
                itemBuilder: (context, i) {
                  final r = widget.result.results[i];
                  final word = widget.result.words.firstWhere(
                    (w) => w.id == r.vocabRecordId,
                    orElse: () => widget.result.words[i],
                  );
                  return ListTile(
                    leading: Icon(
                      r.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: r.isCorrect ? Colors.green : Colors.red,
                    ),
                    title: Text(word.headword),
                    subtitle: Text(word.meaning, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/practice'),
              child: const Text('Luyện tập lại'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Steps

- [ ] Replace `session_result_screen.dart` with implementation above
- [ ] `flutter analyze lib/features/practice/presentation/screens/session_result_screen.dart`
- [ ] `flutter analyze lib/`
- [ ] `flutter test` (expect 57+ tests passing)
- [ ] Commit: `feat(plan3): implement SessionResultScreen with score display and background SM-2 update`
