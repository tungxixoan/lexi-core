import '../../../vocabulary/domain/entities/vocab_record.dart';

final class ExerciseResult {
  const ExerciseResult({
    required this.vocabRecordId,
    required this.quality,
    required this.isCorrect,
  });

  final String vocabRecordId;
  final int quality; // 5 = correct/knew it, 1 = incorrect/didn't know
  final bool isCorrect;
}

final class SessionConfig {
  const SessionConfig({required this.words, required this.aiRatio});
  final List<VocabRecord> words; // pre-shuffled by caller
  final double
      aiRatio; // 0.0–1.0; probability an eligible word gets an AI exercise
}

/// Decides flashcard vs AI for one word. `roll` is a single random value in
/// [0, 1) supplied by the caller (keeps this pure/testable — no RNG inside).
/// A never-reviewed word or no AI key always wins regardless of `aiRatio`;
/// otherwise the word is flashcard iff `roll` falls in the `(1 - aiRatio)`
/// slice. At `aiRatio == 0.7` this reproduces the historical 30/70 split.
bool shouldUseFlashcard(
  VocabRecord word,
  bool aiAvailable,
  double aiRatio,
  double roll,
) {
  if (word.sm2Repetitions == 0 || !aiAvailable) return true;
  // Written as `roll + aiRatio < 1.0` rather than `roll < (1 - aiRatio)`:
  // mathematically equivalent, but avoids a double-precision boundary bug
  // (e.g. `1 - 0.7` is `0.30000000000000004`, not exactly `0.3`) that would
  // otherwise misclassify the `aiRatio == 1 - roll` boundary.
  return roll + aiRatio < 1.0;
}

/// Maps a single random `roll` in [0, 1) to a session AI-mix ratio in
/// [0.20, 0.80] — used once per "Trộn AI" session, never per word.
double drawSessionAiRatio(double roll) => 0.20 + roll * 0.60;

final class SessionResult {
  const SessionResult({
    required this.results,
    required this.words,
  });

  final List<ExerciseResult> results;
  final List<VocabRecord> words; // same order as results

  int get correctCount => results.where((r) => r.isCorrect).length;
  int get totalCount => results.length;
}
