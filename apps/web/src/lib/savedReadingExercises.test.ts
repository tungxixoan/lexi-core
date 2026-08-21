import { describe, expect, it, vi } from "vitest";
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import {
  saveReadingExercise,
  getRandomSavedExercise,
  getAllUsedVocabIds,
  prioritizeUnusedWords,
  type SavedExerciseFilters,
  type SavedReadingExercise,
} from "./savedReadingExercises";
import type { ReadingPassage } from "./readingPassage";
import type { VocabRecord } from "./vocabRecords";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  doc: vi.fn(() => "mock-doc-ref"),
  getDocs: vi.fn(),
  query: vi.fn(() => "mock-query"),
  setDoc: vi.fn(),
  where: vi.fn(() => "mock-where"),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

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

const PASSAGE: ReadingPassage = {
  sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: ["hi"] }],
  vocabIds: ["v1", "v2"],
};

function makeSavedExercise(overrides: Partial<SavedReadingExercise> = {}): SavedReadingExercise {
  return {
    id: "ex-1",
    type: "bilingual",
    passage: PASSAGE,
    generationFilters: { topicIds: ["biz"], maxCefr: "b1", wordCount: 10 },
    targetLanguage: "english",
    createdAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

describe("saveReadingExercise", () => {
  it("creates a new document carrying its own id field, and returns that id", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-doc-id" } as never);
    const filters: SavedExerciseFilters = { topicIds: ["biz"], maxCefr: "b1", wordCount: 10 };

    const newId = await saveReadingExercise("user-123", PASSAGE, filters, "english");

    expect(collection).toHaveBeenCalledWith("mock-db", "users", "user-123", "reading_exercises");
    expect(doc).toHaveBeenCalledWith("mock-collection-ref");
    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-doc-id" },
      expect.objectContaining({
        id: "new-doc-id",
        type: "bilingual",
        passage: PASSAGE,
        generationFilters: filters,
        targetLanguage: "english",
        createdAt: expect.any(String),
      })
    );
    expect(newId).toBe("new-doc-id");
  });
});

describe("getRandomSavedExercise", () => {
  it("queries only by targetLanguage, filters everything else client-side", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    await getRandomSavedExercise("user-123", "english", { topicIds: [], maxCefr: null, wordCount: null });

    expect(where).toHaveBeenCalledWith("targetLanguage", "==", "english");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-where");
    expect(getDocs).toHaveBeenCalledWith("mock-query");
  });

  it("returns null when there are no candidates", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches on topic overlap (at least one shared id), not equality", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: ["biz", "travel"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: ["travel", "food"],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match when there is no topic overlap", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: ["biz"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: ["travel"],
      maxCefr: null,
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches anything when the requested topicIds filter is empty", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: ["biz"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("matches when the saved exercise's level is at or below the requested max", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: "a2", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match when the saved exercise's level is above the requested max", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: "c1", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("does not match a saved exercise with no level cap when the request has a level cap", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches anything when the requested maxCefr is null, regardless of the saved level", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: "c2", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("requires exact word count equality, including null-matches-null", async () => {
    const ex10 = makeSavedExercise({ id: "ex-10", generationFilters: { topicIds: [], maxCefr: null, wordCount: 10 } });
    const exAll = makeSavedExercise({ id: "ex-all", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: ex10.id, data: () => ex10 },
        { id: exAll.id, data: () => exAll },
      ],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", { topicIds: [], maxCefr: null, wordCount: null });

    expect(result?.id).toBe("ex-all");
  });

  it("excludes the given excludeId even if it would otherwise match", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise(
      "user-123",
      "english",
      { topicIds: [], maxCefr: null, wordCount: null },
      ex.id
    );

    expect(result).toBeNull();
  });

  it("picks randomly among multiple matching candidates", async () => {
    const exA = makeSavedExercise({ id: "ex-a", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    const exB = makeSavedExercise({ id: "ex-b", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: exA.id, data: () => exA },
        { id: exB.id, data: () => exB },
      ],
    } as never);
    const randomSpy = vi.spyOn(Math, "random").mockReturnValue(0.99);

    try {
      const result = await getRandomSavedExercise("user-123", "english", {
        topicIds: [],
        maxCefr: null,
        wordCount: null,
      });
      // Math.floor(0.99 * 2) === 1 -> second candidate
      expect(result?.id).toBe("ex-b");
    } finally {
      randomSpy.mockRestore();
    }
  });

  it("uses the real Firestore document id, not any id field inside the document data", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [{ id: "real-doc-id", data: () => ({ ...ex, id: "stale-field-id" }) }],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe("real-doc-id");
  });
});

describe("getAllUsedVocabIds", () => {
  it("unions vocabIds across every saved exercise", async () => {
    const exA = makeSavedExercise({ id: "a", passage: { sentences: [], vocabIds: ["v1", "v2"] } });
    const exB = makeSavedExercise({ id: "b", passage: { sentences: [], vocabIds: ["v2", "v3"] } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: exA.id, data: () => exA },
        { id: exB.id, data: () => exB },
      ],
    } as never);

    const result = await getAllUsedVocabIds("user-123");

    expect(result).toEqual(new Set(["v1", "v2", "v3"]));
  });

  it("returns an empty set when there are no saved exercises", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);
    const result = await getAllUsedVocabIds("user-123");
    expect(result).toEqual(new Set());
  });
});

describe("prioritizeUnusedWords", () => {
  it("puts words not in usedVocabIds ahead of words that are, preserving relative order within each group", () => {
    const w1 = makeRecord({ id: "w1" });
    const w2 = makeRecord({ id: "w2" });
    const w3 = makeRecord({ id: "w3" });

    const result = prioritizeUnusedWords([w1, w2, w3], new Set(["w1"]));

    expect(result.map((w) => w.id)).toEqual(["w2", "w3", "w1"]);
  });

  it("returns the same order when nothing has been used", () => {
    const w1 = makeRecord({ id: "w1" });
    const w2 = makeRecord({ id: "w2" });
    const result = prioritizeUnusedWords([w1, w2], new Set());
    expect(result.map((w) => w.id)).toEqual(["w1", "w2"]);
  });
});
