// lib/features/practice/presentation/providers/practice_session_provider.dart
import 'dart:math';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

part 'practice_session_provider.g.dart';

final class PracticeSessionState {
  const PracticeSessionState({
    required this.words,
    required this.exercises,
    required this.currentIndex,
    required this.results,
    required this.isComplete,
    required this.aiRatio,
  });

  final List<VocabRecord> words;
  final List<Exercise?> exercises; // parallel to words; null = still generating
  final int currentIndex;
  final List<ExerciseResult> results;
  final bool isComplete;
  final double aiRatio; // fixed for the whole session, set once in startSession

  Exercise? get currentExercise =>
      currentIndex < exercises.length ? exercises[currentIndex] : null;

  bool get hasMore => currentIndex < words.length - 1;

  PracticeSessionState copyWith({
    List<VocabRecord>? words,
    List<Exercise?>? exercises,
    int? currentIndex,
    List<ExerciseResult>? results,
    bool? isComplete,
  }) =>
      PracticeSessionState(
        words: words ?? this.words,
        exercises: exercises ?? this.exercises,
        currentIndex: currentIndex ?? this.currentIndex,
        results: results ?? this.results,
        isComplete: isComplete ?? this.isComplete,
        aiRatio: aiRatio,
      );

  static const empty = PracticeSessionState(
    words: [],
    exercises: [],
    currentIndex: 0,
    results: [],
    isComplete: false,
    aiRatio: 0,
  );
}

@riverpod
class PracticeSessionNotifier extends _$PracticeSessionNotifier {
  final _random = Random();

  @override
  AsyncValue<PracticeSessionState> build() =>
      const AsyncValue.data(PracticeSessionState.empty);

  Future<void> startSession(SessionConfig config) async {
    final words = List<VocabRecord>.from(config.words);
    final exercises = List<Exercise?>.filled(words.length, null);
    state = AsyncValue.data(PracticeSessionState(
      words: words,
      exercises: exercises,
      currentIndex: 0,
      results: const [],
      isComplete: false,
      aiRatio: config.aiRatio,
    ));
    await _generateAt(0, words);
    _generateAt(1, words); // background, don't await
  }

  Future<void> _generateAt(int index, List<VocabRecord> words) async {
    if (index >= words.length) return;
    final word = words[index];
    final aiAvailable = ref.read(userSettingsNotifierProvider).aiAvailable;
    final aiRatio = state.valueOrNull?.aiRatio ?? 0;
    final exercise = shouldUseFlashcard(
            word, aiAvailable, aiRatio, _random.nextDouble())
        ? FlashcardExercise(vocabRecord: word)
        : await ref.read(generateExerciseUseCaseProvider).execute(word);

    final current = state.valueOrNull;
    if (current == null) return;
    final updated = List<Exercise?>.from(current.exercises);
    updated[index] = exercise;
    state = AsyncValue.data(current.copyWith(exercises: updated));
  }

  Future<void> recordAndAdvance(ExerciseResult result) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final newResults = [...current.results, result];
    final nextIndex = current.currentIndex + 1;
    final isComplete = nextIndex >= current.words.length;

    state = AsyncValue.data(current.copyWith(
      results: newResults,
      currentIndex: nextIndex,
      isComplete: isComplete,
    ));

    if (!isComplete) {
      _generateAt(nextIndex + 1, current.words);
    }
  }
}
