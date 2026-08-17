import type { VocabRecord } from "./vocabRecords";

const CEFR_ORDER: readonly VocabRecord["cefrLevel"][] = ["a1", "a2", "b1", "b2", "c1", "c2"];

export interface SessionWordFilters {
  topicIds: Set<string>;
  maxCefr: VocabRecord["cefrLevel"] | null;
  count: number | null; // null = "Tất cả" — no truncation
}

function isDue(record: VocabRecord, now: Date): boolean {
  return record.nextReviewAt === null || new Date(record.nextReviewAt).getTime() <= now.getTime();
}

function matchesFilters(record: VocabRecord, filters: SessionWordFilters): boolean {
  if (filters.topicIds.size > 0 && !record.topicIds.some((id) => filters.topicIds.has(id))) {
    return false;
  }
  if (filters.maxCefr !== null) {
    const recordIndex = CEFR_ORDER.indexOf(record.cefrLevel);
    const maxIndex = CEFR_ORDER.indexOf(filters.maxCefr);
    if (recordIndex > maxIndex) return false;
  }
  return true;
}

function shuffle<T>(items: T[]): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// Due words matching the filters, if any exist; otherwise every matching
// word regardless of due date (never leaves the user with an empty session).
export function selectSessionWords(
  records: VocabRecord[],
  filters: SessionWordFilters,
  now: Date = new Date()
): VocabRecord[] {
  const matching = records.filter((r) => matchesFilters(r, filters));
  const due = matching.filter((r) => isDue(r, now));
  const pool = due.length > 0 ? due : matching;
  const shuffled = shuffle(pool);
  return filters.count === null ? shuffled : shuffled.slice(0, filters.count);
}
