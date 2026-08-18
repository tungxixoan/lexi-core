export interface SentenceStats {
  correctChars: number;
  totalChars: number;
  deletedChars: number;
  durationMs: number;
}

// The caller tracks deletedChars itself: increment it whenever the typed
// value's length shrinks compared to the previous value (covers both a
// single backspace and a select-all-and-retype). This function only scores
// the final state of one completed sentence.
export function computeSentenceStats(
  target: string,
  typed: string,
  deletedChars: number,
  durationMs: number
): SentenceStats {
  let correctChars = 0;
  for (let i = 0; i < typed.length; i++) {
    if (typed[i] === target[i]) correctChars++;
  }
  return { correctChars, totalChars: target.length, deletedChars, durationMs };
}

export interface ReadingResultStats {
  overallAccuracy: number;
  deletionRatio: number;
  finalScore: number;
  wpm: number;
}

const DELETION_PENALTY_WEIGHT = 0.5;

export function aggregateSentenceStats(stats: SentenceStats[]): ReadingResultStats {
  const totalCorrect = stats.reduce((sum, s) => sum + s.correctChars, 0);
  const totalChars = stats.reduce((sum, s) => sum + s.totalChars, 0);
  const totalDeleted = stats.reduce((sum, s) => sum + s.deletedChars, 0);
  const totalDurationMs = stats.reduce((sum, s) => sum + s.durationMs, 0);

  const overallAccuracy = totalChars === 0 ? 0 : totalCorrect / totalChars;
  const deletionRatio = totalChars === 0 ? 0 : totalDeleted / totalChars;
  const finalScore = Math.min(1, Math.max(0, overallAccuracy - DELETION_PENALTY_WEIGHT * deletionRatio));
  const minutes = totalDurationMs / 60000;
  const wpm = minutes === 0 ? 0 : totalChars / 5 / minutes;

  return { overallAccuracy, deletionRatio, finalScore, wpm };
}
