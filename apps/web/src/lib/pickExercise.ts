import type { VocabRecord } from "./vocabRecords";

/**
 * Port of `shouldUseFlashcard`/`_pickExercise` in
 * `lib/features/practice/domain/entities/exercise_result.dart` (Flutter).
 *
 * `aiRatio` (0–1) is the probability an eligible word gets an AI-generated
 * exercise instead of a flashcard, for THIS session — drawn once via
 * `drawSessionAiRatio` when "Trộn AI" is chosen, or 0 for "Flashcard" mode.
 * A never-reviewed word (`sm2Repetitions === 0`) or a session with no AI key
 * always gets a flashcard regardless of `aiRatio`.
 *
 * `aiRatio` defaults to 0.7 — the historical hardcoded 30/70 split — so the
 * current caller (`practice/page.tsx`, still on the 2-arg call) keeps its
 * existing behavior until it's wired up to pass a real per-session ratio.
 */
export function shouldUseFlashcard(
  record: Pick<VocabRecord, "sm2Repetitions">,
  aiAvailable: boolean,
  aiRatio: number = 0.7,
  rng: () => number = Math.random,
): boolean {
  if (record.sm2Repetitions === 0 || !aiAvailable) return true;
  // Written as `roll + aiRatio < 1` rather than `roll < 1 - aiRatio`: same
  // Flutter port (exercise_result.dart) hit a double-precision boundary bug
  // here — `1 - 0.7` is `0.30000000000000004`, not exactly `0.3` — which
  // misclassifies the `aiRatio == 1 - roll` boundary. `roll + aiRatio < 1`
  // avoids it (`0.3 + 0.7` rounds to exactly `1` in IEEE 754 double).
  return rng() + aiRatio < 1;
}

/**
 * Maps one random roll to a per-session AI-mix ratio in [0.20, 0.80) — drawn
 * ONCE when a "Trộn AI" session starts, never re-drawn mid-session or per word.
 */
export function drawSessionAiRatio(rng: () => number = Math.random): number {
  return 0.2 + rng() * 0.6;
}
