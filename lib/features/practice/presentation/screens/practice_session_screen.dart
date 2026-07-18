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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _buildExerciseWidget(exercise),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildExerciseWidget(Exercise exercise) {
    // Keyed by the word so each new exercise gets a fresh State — otherwise
    // Flutter reuses the previous word's State (revealed/selected/submitted
    // flags) since consecutive exercises share the same widget type.
    final key = ValueKey(exercise.vocabRecord.id);
    return switch (exercise) {
      FlashcardExercise e => FlashcardWidget(key: key, exercise: e, onResult: _onResult),
      MultipleChoiceExercise e => MultipleChoiceWidget(key: key, exercise: e, onResult: _onResult),
      FillInBlankExercise e => FillInBlankWidget(key: key, exercise: e, onResult: _onResult),
      TranslationExercise e => TranslationExerciseWidget(key: key, exercise: e, onResult: _onResult),
    };
  }
}
