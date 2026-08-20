export interface SentenceStats {
  correctChars: number;
  totalChars: number;
  deletedChars: number;
  mistakeChars: number;
  durationMs: number;
}

// Index-wise mismatch count between what's typed so far and the target,
// over the typed prefix only. Exported so the caller can track a running
// peak across keystrokes (see mistakeChars below) without duplicating the
// comparison logic.
export function countMismatches(target: string, typed: string): number {
  let mismatches = 0;
  for (let i = 0; i < typed.length; i++) {
    if (typed[i] !== target[i]) mismatches++;
  }
  return mismatches;
}

// The caller tracks deletedChars and mistakeChars itself, across every
// keystroke of one sentence: deletedChars increments whenever the typed
// value's length shrinks (a backspace or a select-all-and-retype);
// mistakeChars is the running max of countMismatches(target, typed) seen at
// any point while typing. Both matter because typed always equals target by
// the time this is called (that's what ends a sentence), so correctChars
// always equals totalChars here — mistakeChars is what actually captures
// wrong keystrokes the user corrected along the way.
export function computeSentenceStats(
  target: string,
  typed: string,
  deletedChars: number,
  mistakeChars: number,
  durationMs: number
): SentenceStats {
  let correctChars = 0;
  for (let i = 0; i < typed.length; i++) {
    if (typed[i] === target[i]) correctChars++;
  }
  return { correctChars, totalChars: target.length, deletedChars, mistakeChars, durationMs };
}

export interface ReadingResultStats {
  overallAccuracy: number;
  typingAccuracy: number;
  deletionRatio: number;
  finalScore: number;
  wpm: number;
}

const DELETION_PENALTY_WEIGHT = 0.5;

export function aggregateSentenceStats(stats: SentenceStats[]): ReadingResultStats {
  const totalCorrect = stats.reduce((sum, s) => sum + s.correctChars, 0);
  const totalChars = stats.reduce((sum, s) => sum + s.totalChars, 0);
  const totalDeleted = stats.reduce((sum, s) => sum + s.deletedChars, 0);
  const totalMistakes = stats.reduce((sum, s) => sum + s.mistakeChars, 0);
  const totalDurationMs = stats.reduce((sum, s) => sum + s.durationMs, 0);

  const overallAccuracy = totalChars === 0 ? 0 : totalCorrect / totalChars;
  // Every completed sentence matches the target exactly by construction, so
  // overallAccuracy is always 1 — it's kept only because finalScore is
  // defined in terms of it. typingAccuracy is the real "how many mistakes
  // did you make along the way" signal, derived from the live peak-mismatch
  // tracking above; it's what the result screen's "Độ chính xác" card shows.
  const typingAccuracy = totalChars === 0 ? 0 : Math.max(0, 1 - totalMistakes / totalChars);
  const deletionRatio = totalChars === 0 ? 0 : totalDeleted / totalChars;
  const finalScore = Math.min(1, Math.max(0, overallAccuracy - DELETION_PENALTY_WEIGHT * deletionRatio));
  const minutes = totalDurationMs / 60000;
  const wpm = minutes === 0 ? 0 : totalChars / 5 / minutes;

  return { overallAccuracy, typingAccuracy, deletionRatio, finalScore, wpm };
}
