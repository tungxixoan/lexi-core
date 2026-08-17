// Ports lib/features/practice/domain/use_cases/compute_sm2_use_case.dart
// exactly — verified against that file. This is shared production data with
// the Flutter app; do not change the constants or branch structure without
// updating both sides.
export interface Sm2Fields {
  sm2Repetitions: number;
  sm2EaseFactor: number;
  sm2Interval: number;
  nextReviewAt: string;
  updatedAt: string;
}

const MIN_EASE_FACTOR = 1.3;
const MAX_EASE_FACTOR = 2.5;

function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

export function computeSm2(
  record: { sm2Repetitions: number; sm2EaseFactor: number; sm2Interval: number },
  quality: number,
  now: Date = new Date()
): Sm2Fields {
  if (quality < 3) {
    return {
      sm2Repetitions: 0,
      sm2EaseFactor: record.sm2EaseFactor,
      sm2Interval: 1,
      nextReviewAt: addDays(now, 1).toISOString(),
      updatedAt: now.toISOString(),
    };
  }

  const newInterval =
    record.sm2Repetitions === 0
      ? 1
      : record.sm2Repetitions === 1
        ? 6
        : Math.round(record.sm2Interval * record.sm2EaseFactor);

  const newEaseFactor = clamp(
    record.sm2EaseFactor + 0.1 - (5 - quality) * 0.08,
    MIN_EASE_FACTOR,
    MAX_EASE_FACTOR
  );

  return {
    sm2Repetitions: record.sm2Repetitions + 1,
    sm2EaseFactor: newEaseFactor,
    sm2Interval: newInterval,
    nextReviewAt: addDays(now, newInterval).toISOString(),
    updatedAt: now.toISOString(),
  };
}
