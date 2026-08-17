import { describe, expect, it } from "vitest";
import { selectSessionWords } from "./practiceSession";
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

const NOW = new Date("2026-08-16T12:00:00.000Z");

describe("selectSessionWords", () => {
  it("prefers due words (null or past nextReviewAt) over not-yet-due ones", () => {
    const due = makeRecord({ id: "due-1", nextReviewAt: null });
    const notDue = makeRecord({ id: "not-due-1", nextReviewAt: "2099-01-01T00:00:00.000Z" });

    const result = selectSessionWords(
      [due, notDue],
      { topicIds: new Set(), maxCefr: null, count: null },
      NOW
    );

    expect(result.map((r) => r.id)).toEqual(["due-1"]);
  });

  it("falls back to any matching word when none are due", () => {
    const notDue1 = makeRecord({ id: "a", nextReviewAt: "2099-01-01T00:00:00.000Z" });
    const notDue2 = makeRecord({ id: "b", nextReviewAt: "2099-01-01T00:00:00.000Z" });

    const result = selectSessionWords(
      [notDue1, notDue2],
      { topicIds: new Set(), maxCefr: null, count: null },
      NOW
    );

    expect(result.map((r) => r.id).sort()).toEqual(["a", "b"]);
  });

  it("treats a nextReviewAt exactly equal to now as due", () => {
    const dueNow = makeRecord({ id: "x", nextReviewAt: NOW.toISOString() });
    const result = selectSessionWords(
      [dueNow],
      { topicIds: new Set(), maxCefr: null, count: null },
      NOW
    );
    expect(result.map((r) => r.id)).toEqual(["x"]);
  });

  it("filters by topic (OR within the selected topics)", () => {
    const business = makeRecord({ id: "biz", topicIds: ["business"] });
    const travel = makeRecord({ id: "travel", topicIds: ["travel"] });
    const neither = makeRecord({ id: "neither", topicIds: ["academic"] });

    const result = selectSessionWords(
      [business, travel, neither],
      { topicIds: new Set(["business", "travel"]), maxCefr: null, count: null },
      NOW
    );

    expect(result.map((r) => r.id).sort()).toEqual(["biz", "travel"]);
  });

  it("filters by maximum CEFR level", () => {
    const a1 = makeRecord({ id: "a1", cefrLevel: "a1" });
    const c1 = makeRecord({ id: "c1", cefrLevel: "c1" });

    const result = selectSessionWords([a1, c1], { topicIds: new Set(), maxCefr: "b1", count: null }, NOW);

    expect(result.map((r) => r.id)).toEqual(["a1"]);
  });

  it("truncates to the requested count", () => {
    const records = Array.from({ length: 10 }, (_, i) => makeRecord({ id: `w${i}` }));

    const result = selectSessionWords(records, { topicIds: new Set(), maxCefr: null, count: 3 }, NOW);

    expect(result).toHaveLength(3);
  });

  it("returns every matching word when count is null ('Tất cả')", () => {
    const records = Array.from({ length: 10 }, (_, i) => makeRecord({ id: `w${i}` }));

    const result = selectSessionWords(records, { topicIds: new Set(), maxCefr: null, count: null }, NOW);

    expect(result).toHaveLength(10);
  });
});
