import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../services/tts_service.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';
import '../providers/practice_session_provider.dart';
import '../widgets/fill_in_blank_widget.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/multiple_choice_widget.dart';
import '../widgets/translation_exercise_widget.dart';

class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({super.key, required this.config});

  /// Null only while this route is rebuilt underneath its `result` child —
  /// see `app_router.dart`. In that state the screen renders nothing.
  final SessionConfig? config;

  @override
  ConsumerState<PracticeSessionScreen> createState() =>
      _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends ConsumerState<PracticeSessionScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    if (config == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(practiceSessionNotifierProvider.notifier).startSession(config);
      if (mounted) setState(() => _started = true);
    });
  }

  void _onResult(ExerciseResult result) {
    ref.read(practiceSessionNotifierProvider.notifier).recordAndAdvance(result);
  }

  /// A "speak the headword" callback, or null when the target language has no
  /// Piper voice (zh/ko/ja) — matches the dictionary result widgets.
  VoidCallback? _pronounceFor(VocabRecord record) {
    final language = ref.read(userSettingsNotifierProvider).targetLanguage;
    if (language.ttsCloudCode == null) return null;
    return () => ref
        .read(ttsServiceProvider)
        .pronounce(record.headword, language, tier: PronunciationTier.word);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt underneath the `result` child route — nothing to show.
    if (widget.config == null) return const SizedBox.shrink();

    final sessionAsync = ref.watch(practiceSessionNotifierProvider);

    // A hardware/browser back mid-session would pop the nested route with no
    // clean teardown. Intercept it and abandon to the practice hub — same as
    // the "Thoát" action.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/practice/vocab');
      },
      child: sessionAsync.when(
        loading: () => const BloomScaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) => BloomScaffold(body: Center(child: Text('Lỗi: $e'))),
        data: (session) {
          if (session.isComplete && _started) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/practice/session/result',
                    extra: SessionResult(
                        results: session.results, words: session.words));
              }
            });
            return const BloomScaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          final total = session.words.length;
          final current = session.currentIndex;
          final exercise = session.currentExercise;

          return BloomScaffold(
            appBar: BloomAppBar(
              title: '${current + 1} / $total',
              automaticallyImplyLeading: false,
              actions: [
                BloomPillButton(
                  label: 'Thoát',
                  variant: BloomButtonVariant.link,
                  onPressed: () => context.go('/practice/vocab'),
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child:
                      BloomProgressBar(value: total > 0 ? current / total : 0),
                ),
                Expanded(
                  child: exercise == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseWidget(Exercise exercise) {
    // Keyed by the word so each new exercise gets a fresh State — otherwise
    // Flutter reuses the previous word's State (revealed/selected/submitted
    // flags) since consecutive exercises share the same widget type.
    final key = ValueKey(exercise.vocabRecord.id);
    return switch (exercise) {
      FlashcardExercise e => FlashcardWidget(
          key: key,
          exercise: e,
          onResult: _onResult,
          onPronounce: _pronounceFor(e.vocabRecord),
        ),
      MultipleChoiceExercise e =>
        MultipleChoiceWidget(key: key, exercise: e, onResult: _onResult),
      FillInBlankExercise e =>
        FillInBlankWidget(key: key, exercise: e, onResult: _onResult),
      TranslationExercise e =>
        TranslationExerciseWidget(key: key, exercise: e, onResult: _onResult),
    };
  }
}
