import { describe, expect, it } from "vitest";
import { isFilterActive, matchesFilters, type VocabFilterState } from "./vocabFilters";
import type { VocabRecord } from "./vocabRecords";

const BASE: VocabRecord = {
  id: "1",
  headword: "test",
  inputType: "word",
  ipa: "",
  meaning: "",
  examples: [],
  personalNotes: "",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "b2",
  activeContext: "business",
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 0,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

const EMPTY: VocabFilterState = { dueOnly: false, topicIds: new Set(), cefrLevels: new Set() };
const isDueTrue = () => true;
const isDueFalse = () => false;

describe("matchesFilters", () => {
  it("matches everything when no filter is active", () => {
    expect(matchesFilters(BASE, EMPTY, isDueFalse)).toBe(true);
  });

  it("dueOnly filters out non-due records", () => {
    expect(matchesFilters(BASE, { ...EMPTY, dueOnly: true }, isDueTrue)).toBe(true);
    expect(matchesFilters(BASE, { ...EMPTY, dueOnly: true }, isDueFalse)).toBe(false);
  });

  it("topicIds is OR within the facet", () => {
    const filters = { ...EMPTY, topicIds: new Set(["business", "travel"]) };
    expect(matchesFilters(BASE, filters, isDueFalse)).toBe(true); // BASE has "business"
    const filtersNoMatch = { ...EMPTY, topicIds: new Set(["travel", "academic"]) };
    expect(matchesFilters(BASE, filtersNoMatch, isDueFalse)).toBe(false);
  });

  it("cefrLevels is OR within the facet", () => {
    const filters = { ...EMPTY, cefrLevels: new Set(["b2", "c1"]) };
    expect(matchesFilters(BASE, filters, isDueFalse)).toBe(true); // BASE is "b2"
    const filtersNoMatch = { ...EMPTY, cefrLevels: new Set(["a1", "c2"]) };
    expect(matchesFilters(BASE, filtersNoMatch, isDueFalse)).toBe(false);
  });

  it("combines facets with AND", () => {
    // BASE is topic "business", level "b2"
    const matchesBoth = { ...EMPTY, topicIds: new Set(["business"]), cefrLevels: new Set(["b2"]) };
    expect(matchesFilters(BASE, matchesBoth, isDueFalse)).toBe(true);

    const topicOnlyMatches = {
      ...EMPTY,
      topicIds: new Set(["business"]),
      cefrLevels: new Set(["c1"]), // BASE is b2, not c1 -> AND fails
    };
    expect(matchesFilters(BASE, topicOnlyMatches, isDueFalse)).toBe(false);
  });
});

describe("isFilterActive", () => {
  it("is false when every facet is empty", () => {
    expect(isFilterActive(EMPTY)).toBe(false);
  });

  it("is true when any facet is non-empty", () => {
    expect(isFilterActive({ ...EMPTY, dueOnly: true })).toBe(true);
    expect(isFilterActive({ ...EMPTY, topicIds: new Set(["business"]) })).toBe(true);
    expect(isFilterActive({ ...EMPTY, cefrLevels: new Set(["b2"]) })).toBe(true);
  });
});
