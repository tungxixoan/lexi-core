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
  });

  final List<VocabRecord> words;
  final List<Exercise?> exercises; // parallel to words; null = still generating
  final int currentIndex;
  final List<ExerciseResult> results;
  final bool isComplete;

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
      );

  static const empty = PracticeSessionState(
    words: [],
    exercises: [],
    currentIndex: 0,
    results: [],
    isComplete: false,
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
    ));
    await _generateAt(0, words);
    _generateAt(1, words); // background, don't await
  }

  Future<void> _generateAt(int index, List<VocabRecord> words) async {
    if (index >= words.length) return;
    final word = words[index];
    final aiEnabled = ref.read(userSettingsNotifierProvider).aiEnabled;
    final exercise = await _pickExercise(word, aiEnabled);

    final current = state.valueOrNull;
    if (current == null) return;
    final updated = List<Exercise?>.from(current.exercises);
    updated[index] = exercise;
    state = AsyncValue.data(current.copyWith(exercises: updated));
  }

  Future<Exercise> _pickExercise(VocabRecord word, bool aiEnabled) async {
    if (word.sm2Repetitions == 0 || !aiEnabled) {
      return FlashcardExercise(vocabRecord: word);
    }
    if (_random.nextDouble() < 0.30) {
      return FlashcardExercise(vocabRecord: word);
    }
    return ref
        .read(generateExerciseUseCaseProvider)
        .execute(word, aiEnabled: aiEnabled);
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
