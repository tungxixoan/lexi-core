import type { Topic } from "./topics";

const FULL_MASTERY_REPETITIONS = 6;
const DEFAULT_EASE_FACTOR = 2.5;

/**
 * SM-2 doesn't produce a 0-100 mastery score directly (see
 * ComputeSm2UseCase in the Flutter app — it only tracks repetitions/ease/
 * interval). This blends how many successful reviews a word has survived
 * with how easy those reviews were, so a word reviewed many times but
 * always graded "barely correct" reads as partially mastered rather than
 * fully mastered.
 */
export function computeMasteryPercent(record: {
  sm2Repetitions: number;
  sm2EaseFactor: number;
}): number {
  const repetitionsRatio =
    Math.min(record.sm2Repetitions, FULL_MASTERY_REPETITIONS) / FULL_MASTERY_REPETITIONS;
  const easeRatio = record.sm2EaseFactor / DEFAULT_EASE_FACTOR;
  return Math.round(100 * repetitionsRatio * easeRatio);
}

export function formatDueLabel(nextReviewAt: string | null, now: Date): string {
  if (nextReviewAt === null) return "chưa ôn";
  const due = new Date(nextReviewAt);
  if (due.getTime() <= now.getTime()) return "ôn hôm nay";
  const days = Math.ceil((due.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  return `ôn sau ${days} ngày`;
}

export function resolveTopicNames(topicIds: string[], topics: Topic[]): string[] {
  const byId = new Map(topics.map((t) => [t.id, t.name]));
  return topicIds.map((id) => byId.get(id) ?? id);
}

// Vocab bank headwords are stored with a capital first letter ("Follow up",
// not "follow up") for consistent display. Applied on every new save and by
// the one-off `scripts/capitalize-vocab-headwords.js` migration. Idempotent;
// leaves already-capitalized, acronym, and non-letter-initial words alone.
export function capitalizeHeadword(s: string): string {
  const first = s[0];
  if (first && first.toLowerCase() === first && first.toUpperCase() !== first) {
    return first.toUpperCase() + s.slice(1);
  }
  return s;
}
