import { describe, expect, it } from "vitest";
import { computeLearningStats, MASTERED_INTERVAL_THRESHOLD } from "./learningStats";
import type { VocabRecord } from "./vocabRecords";

function makeRecord(overrides: Partial<VocabRecord>): VocabRecord {
  return {
    id: "id",
    headword: "word",
    inputType: "word",
    ipa: "",
    meaning: "nghĩa",
    examples: [],
    personalNotes: "",
    topicIds: [],
    targetLanguage: "english",
    cefrLevel: "b1",
    activeContext: "general",
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    nextReviewAt: null,
    sm2Repetitions: 0,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: "",
    synonyms: [],
    ...overrides,
  };
}

describe("computeLearningStats", () => {
  it("returns all zeros for an empty record list", () => {
    const stats = computeLearningStats([]);
    expect(stats.dueCount).toBe(0);
    expect(stats.masteredCount).toBe(0);
    expect(stats.totalCount).toBe(0);
    expect(stats.cefrBreakdown).toEqual({ a1: 0, a2: 0, b1: 0, b2: 0, c1: 0, c2: 0 });
  });

  it("counts due-by-null and due-by-past-date, excludes future nextReviewAt", () => {
    const now = new Date("2026-08-25T12:00:00.000Z");
    const records = [
      makeRecord({ id: "1", nextReviewAt: null }), // due
      makeRecord({ id: "2", nextReviewAt: "2026-08-25T11:00:00.000Z" }), // due (past)
      makeRecord({ id: "3", nextReviewAt: "2026-09-01T00:00:00.000Z" }), // not due (future)
    ];
    const stats = computeLearningStats(records, now);
    expect(stats.dueCount).toBe(2);
  });

  it("mastered threshold is exactly sm2Interval >= 21", () => {
    const records = [
      makeRecord({ id: "1", sm2Interval: 20 }),
      makeRecord({ id: "2", sm2Interval: 21 }),
      makeRecord({ id: "3", sm2Interval: 100 }),
    ];
    const stats = computeLearningStats(records);
    expect(stats.masteredCount).toBe(2);
    expect(MASTERED_INTERVAL_THRESHOLD).toBe(21);
  });

  it("builds a CEFR breakdown across all 6 levels, including zero-count levels", () => {
    const records = [
      makeRecord({ id: "1", cefrLevel: "a1" }),
      makeRecord({ id: "2", cefrLevel: "a1" }),
      makeRecord({ id: "3", cefrLevel: "b2" }),
    ];
    const stats = computeLearningStats(records);
    expect(stats.cefrBreakdown.a1).toBe(2);
    expect(stats.cefrBreakdown.b2).toBe(1);
    expect(stats.cefrBreakdown.c1).toBe(0);
    expect(stats.totalCount).toBe(3);
  });

  it("counts a word due at exactly `now` as due — matches practiceSession.ts's isDue exactly, not Flutter's strict isBefore", () => {
    const now = new Date("2026-08-25T12:00:00.000Z");
    const records = [
      makeRecord({ id: "1", nextReviewAt: "2026-08-25T12:00:00.000Z" }), // exactly now
    ];
    const stats = computeLearningStats(records, now);
    expect(stats.dueCount).toBe(1);
  });
});
