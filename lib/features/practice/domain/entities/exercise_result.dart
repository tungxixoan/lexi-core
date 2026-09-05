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
  const SessionConfig({required this.words});
  final List<VocabRecord> words; // pre-shuffled by caller
}

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
