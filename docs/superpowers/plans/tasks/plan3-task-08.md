# Plan 3 — Task 08: PracticeSessionScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 04 (placeholder exists), Task 05 (session provider), Task 06 (exercise widgets)

## Global Constraints
(see `plan3-global-constraints.md`)

## What This Task Delivers

Replace placeholder `PracticeSessionScreen` with real session UI:
- Progress bar + "N / total" in AppBar
- Shows loading spinner while current exercise generates (null state)
- Dispatches correct widget per exercise type via sealed class switch
- On `onResult`: calls `recordAndAdvance()` on session notifier
- When `isComplete`: navigates to `/practice/session/result` with `SessionResult`
- "Thoát" button → navigates back to `/practice`

## Files

- Modify: `lib/features/practice/presentation/screens/practice_session_screen.dart`

## Implementation

```dart
// lib/features/practice/presentation/screens/practice_session_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';
import '../providers/practice_session_provider.dart';
import '../widgets/fill_in_blank_widget.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/multiple_choice_widget.dart';
import '../widgets/translation_exercise_widget.dart';

class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({super.key, required this.config});
  final SessionConfig config;

  @override
  ConsumerState<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends ConsumerState<PracticeSessionScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(practiceSessionNotifierProvider.notifier)
          .startSession(widget.config);
      setState(() => _started = true);
    });
  }

  void _onResult(ExerciseResult result) {
    ref.read(practiceSessionNotifierProvider.notifier).recordAndAdvance(result);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(practiceSessionNotifierProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
      data: (session) {
        if (session.isComplete && _started) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/practice/session/result',
                  extra: SessionResult(results: session.results, words: session.words));
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final total = session.words.length;
        final current = session.currentIndex;
        final exercise = session.currentExercise;

        return Scaffold(
          appBar: AppBar(
            title: Text('${current + 1} / $total'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(value: total > 0 ? current / total : 0),
            ),
            automaticallyImplyLeading: false,
            actions: [
              TextButton(
                onPressed: () => context.go('/practice'),
                child: const Text('Thoát'),
              ),
            ],
          ),
          body: exercise == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildExerciseWidget(exercise),
                ),
        );
      },
    );
  }

  Widget _buildExerciseWidget(Exercise exercise) {
    return switch (exercise) {
      FlashcardExercise e => FlashcardWidget(exercise: e, onResult: _onResult),
      MultipleChoiceExercise e => MultipleChoiceWidget(exercise: e, onResult: _onResult),
      FillInBlankExercise e => FillInBlankWidget(exercise: e, onResult: _onResult),
      TranslationExercise e => TranslationExerciseWidget(exercise: e, onResult: _onResult),
    };
  }
}
```

## Steps

- [ ] Replace `practice_session_screen.dart` with implementation above
- [ ] `flutter analyze lib/features/practice/presentation/screens/practice_session_screen.dart`
- [ ] `flutter test`
- [ ] Commit: `feat(plan3): implement PracticeSessionScreen with lazy exercise display and navigation`
