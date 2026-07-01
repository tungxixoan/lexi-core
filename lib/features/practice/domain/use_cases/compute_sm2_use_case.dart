import '../../../vocabulary/domain/entities/vocab_record.dart';

class ComputeSm2UseCase {
  const ComputeSm2UseCase();

  VocabRecord compute(VocabRecord record, int quality) {
    final now = DateTime.now();
    if (quality < 3) {
      return record.copyWith(
        sm2Repetitions: 0,
        sm2Interval: 1,
        nextReviewAt: now.add(const Duration(days: 1)),
        updatedAt: now,
      );
    }
    final newInterval = switch (record.sm2Repetitions) {
      0 => 1,
      1 => 6,
      _ => (record.sm2Interval * record.sm2EaseFactor).round(),
    };
    final newEF = (record.sm2EaseFactor + 0.1 - (5 - quality) * 0.08)
        .clamp(1.3, 2.5);
    return record.copyWith(
      sm2Repetitions: record.sm2Repetitions + 1,
      sm2Interval: newInterval,
      sm2EaseFactor: newEF,
      nextReviewAt: now.add(Duration(days: newInterval)),
      updatedAt: now,
    );
  }
}
