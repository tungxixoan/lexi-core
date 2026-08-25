import type { VocabRecord } from "./vocabRecords";

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];

export interface LearningStats {
  dueCount: number;
  masteredCount: number;
  totalCount: number;
  cefrBreakdown: Record<CefrLevel, number>;
}

// Ports StatsService.computeStats()'s mastered threshold exactly.
export const MASTERED_INTERVAL_THRESHOLD = 21;

function isDue(record: VocabRecord, now: Date): boolean {
  return record.nextReviewAt === null || new Date(record.nextReviewAt).getTime() <= now.getTime();
}

// Ports StatsService.computeStats()'s due/mastered/CEFR logic exactly —
// the streak/weeklyLog half lives in dailyActivity.ts instead, since that
// part is persisted (Firestore) rather than derived fresh every call.
export function computeLearningStats(records: VocabRecord[], now: Date = new Date()): LearningStats {
  let dueCount = 0;
  let masteredCount = 0;
  const cefrBreakdown = Object.fromEntries(CEFR_LEVELS.map((l) => [l, 0])) as Record<CefrLevel, number>;

  for (const r of records) {
    if (isDue(r, now)) dueCount++;
    if (r.sm2Interval >= MASTERED_INTERVAL_THRESHOLD) masteredCount++;
    cefrBreakdown[r.cefrLevel] = (cefrBreakdown[r.cefrLevel] ?? 0) + 1;
  }

  return { dueCount, masteredCount, totalCount: records.length, cefrBreakdown };
}
