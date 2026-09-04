import type { VocabRecord } from "./vocabRecords";

/**
 * Port of `_pickExercise` in
 * `lib/features/practice/presentation/providers/practice_session_provider.dart`.
 *
 * Pure decision only — the caller runs the async `generateExercise` when this
 * returns `false`. A word that has never been reviewed (`sm2Repetitions === 0`)
 * or a session with no AI key always gets a flashcard; otherwise 30% of the
 * time it's still a flashcard, 70% an AI-generated exercise.
 */
export function shouldUseFlashcard(
  record: Pick<VocabRecord, "sm2Repetitions">,
  aiAvailable: boolean,
  rng: () => number = Math.random,
): boolean {
  if (record.sm2Repetitions === 0 || !aiAvailable) return true;
  return rng() < 0.3;
}
