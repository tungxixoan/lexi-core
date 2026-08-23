import { describe, expect, it, vi } from "vitest";
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import {
  saveReadingExercise,
  getRandomSavedExercise,
  getAllUsedVocabIds,
  prioritizeUnusedWords,
  type BilingualFilters,
  type SavedReadingExercise,
} from "./savedReadingExercises";
import type { ReadingPassage } from "./readingPassage";
import type { VocabRecord } from "./vocabRecords";
import type { Part6Set } from "./part6";

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

// Minimal fixture shaped like the real Part5Set (Task 3) — not imported from
// part5.ts, which doesn't exist yet. This proves the generic type/filter
// dispatch works for a second type before that module is written.
interface FakePart5Set {
  questions: { sentenceWithBlank: string; options: string[]; correctIndex: number; explanation: string }[];
}
interface FakeToeicFilters {
  topicIds: string[];
  volumes: string[];
}
const PART5_PASSAGE: FakePart5Set = {
  questions: [{ sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "..." }],
};

const PART6_PASSAGE: Part6Set = {
  passages: [
    {
      passageText: "... (1)___ ... (2)___ ... (3)___ ... (4)___ ...",
      questions: [
        { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." },
        { options: ["a", "b", "c", "d"], correctIndex: 1, explanation: "B." },
        { options: ["a", "b", "c", "d"], correctIndex: 2, explanation: "C." },
        { options: ["a", "b", "c", "d"], correctIndex: 3, explanation: "D." },
      ],
    },
  ],
};

function makeBilingualExercise(overrides: Partial<Extract<SavedReadingExercise, { type: "bilingual" }>> = {}) {
  return {
    id: "ex-1",
    type: "bilingual" as const,
    passage: PASSAGE,
    generationFilters: { topicIds: ["biz"], maxCefr: "b1" as const, wordCount: 10 },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

function makePart5Exercise(overrides: Partial<{ id: string; generationFilters: FakeToeicFilters }> = {}) {
  return {
    id: "p5-1",
    type: "part5" as const,
    passage: PART5_PASSAGE,
    generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

function makePart6Exercise(overrides: Partial<{ id: string; generationFilters: FakeToeicFilters }> = {}) {
  return {
    id: "p6-1",
    type: "part6" as const,
    passage: PART6_PASSAGE,
    generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

describe("saveReadingExercise", () => {
  it("creates a bilingual document carrying its own id field, and returns that id", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-doc-id" } as never);
    const filters: BilingualFilters = { topicIds: ["biz"], maxCefr: "b1", wordCount: 10 };

    const newId = await saveReadingExercise("user-123", "bilingual", PASSAGE, filters, "english");

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

  it("creates a part5 document the same way, with type: 'part5' in the stored record", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-p5-id" } as never);
    const filters = { topicIds: ["biz-1"], volumes: ["vol3"] };

    const newId = await saveReadingExercise("user-123", "part5", PART5_PASSAGE, filters, "english");

    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-p5-id" },
      expect.objectContaining({
        id: "new-p5-id",
        type: "part5",
        passage: PART5_PASSAGE,
        generationFilters: filters,
        targetLanguage: "english",
      })
    );
    expect(newId).toBe("new-p5-id");
  });

  it("creates a part6 document carrying its own id field, and returns that id", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-p6-id" } as never);
    const filters = { topicIds: ["biz-1"], volumes: ["vol3"] };

    const newId = await saveReadingExercise("user-123", "part6", PART6_PASSAGE, filters, "english");

    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-p6-id" },
      expect.objectContaining({
        id: "new-p6-id",
        type: "part6",
        passage: PART6_PASSAGE,
        generationFilters: filters,
        targetLanguage: "english",
      })
    );
    expect(newId).toBe("new-p6-id");
  });
});

describe("getRandomSavedExercise", () => {
  it("queries only by targetLanguage, filters everything else client-side", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    await getRandomSavedExercise("user-123", "english", "bilingual", { topicIds: [], maxCefr: null, wordCount: null });

    expect(where).toHaveBeenCalledWith("targetLanguage", "==", "english");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-where");
    expect(getDocs).toHaveBeenCalledWith("mock-query");
  });

  it("returns null when there are no candidates", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches on topic overlap (at least one shared id), not equality", async () => {
    const ex = makeBilingualExercise({ generationFilters: { topicIds: ["biz", "travel"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: ["travel", "food"],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match when there is no topic overlap", async () => {
    const ex = makeBilingualExercise({ generationFilters: { topicIds: ["biz"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: ["travel"],
      maxCefr: null,
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches anything when the requested topicIds filter is empty", async () => {
    const ex = makeBilingualExercise({ generationFilters: { topicIds: ["biz"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("matches when the saved exercise's level is at or below the requested max", async () => {
    const ex = makeBilingualExercise({ generationFilters: { topicIds: [], maxCefr: "a2", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match when the saved exercise's level is above the requested max", async () => {
    const ex = makeBilingualExercise({ generationFilters: { topicIds: [], maxCefr: "c1", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("does not match a bilingual exercise with no level cap when the request has a level cap", async () => {
    const ex = makeBilingualExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches anything when the requested maxCefr is null, regardless of the saved level", async () => {
    const ex = makeBilingualExercise({ generationFilters: { topicIds: [], maxCefr: "c2", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("requires exact word count equality, including null-matches-null", async () => {
    const ex10 = makeBilingualExercise({ id: "ex-10", generationFilters: { topicIds: [], maxCefr: null, wordCount: 10 } });
    const exAll = makeBilingualExercise({ id: "ex-all", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: ex10.id, data: () => ex10 },
        { id: exAll.id, data: () => exAll },
      ],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", { topicIds: [], maxCefr: null, wordCount: null });

    expect(result?.id).toBe("ex-all");
  });

  it("excludes the given excludeId even if it would otherwise match", async () => {
    const ex = makeBilingualExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise(
      "user-123",
      "english",
      "bilingual",
      { topicIds: [], maxCefr: null, wordCount: null },
      ex.id
    );

    expect(result).toBeNull();
  });

  it("picks randomly among multiple matching candidates", async () => {
    const exA = makeBilingualExercise({ id: "ex-a", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    const exB = makeBilingualExercise({ id: "ex-b", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: exA.id, data: () => exA },
        { id: exB.id, data: () => exB },
      ],
    } as never);
    const randomSpy = vi.spyOn(Math, "random").mockReturnValue(0.99);

    try {
      const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
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
    const ex = makeBilingualExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [{ id: "real-doc-id", data: () => ({ ...ex, id: "stale-field-id" }) }],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe("real-doc-id");
  });

  it("never returns a document of a different type, even if its stored filters would otherwise satisfy the shape", async () => {
    const p5 = makePart5Exercise();
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "bilingual", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches part5 exercises by topic overlap and volume overlap", async () => {
    const p5 = makePart5Exercise({ generationFilters: { topicIds: ["biz-1", "travel-1"], volumes: ["vol2", "vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      topicIds: ["travel-1", "food-1"],
      volumes: ["vol3", "vol4"],
    } as never);

    expect(result?.id).toBe(p5.id);
  });

  it("does not match a part5 exercise when there is no topic overlap", async () => {
    const p5 = makePart5Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      topicIds: ["travel-1"],
      volumes: [],
    } as never);

    expect(result).toBeNull();
  });

  it("does not throw on a pre-migration part5 doc with no topicIds field, and treats it as not overlapping", async () => {
    // Simulates a Part 5 exercise saved before the topic-based filter
    // migration (cb82326): old docs have `{ appContext, volumes }` with no
    // `topicIds` field at all, not even an empty array.
    const preMigrationP5 = makePart5Exercise({
      generationFilters: { volumes: [] } as unknown as FakeToeicFilters,
    });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: preMigrationP5.id, data: () => preMigrationP5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      topicIds: ["travel-1"],
      volumes: [],
    } as never);

    expect(result).toBeNull();
  });

  it("matches a part5 exercise on any topic when the requested topicIds filter is empty", async () => {
    const p5 = makePart5Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      topicIds: [],
      volumes: ["vol4"],
    } as never);

    expect(result?.id).toBe(p5.id);
  });

  it("matches part6 exercises by topic overlap and volume overlap, mirroring part5's matching", async () => {
    const p6 = makePart6Exercise({ generationFilters: { topicIds: ["biz-1", "travel-1"], volumes: ["vol2", "vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p6.id, data: () => p6 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part6", {
      topicIds: ["travel-1", "food-1"],
      volumes: ["vol3", "vol4"],
    } as never);

    expect(result?.id).toBe(p6.id);
  });

  it("does not match a part6 exercise when there is no topic overlap", async () => {
    const p6 = makePart6Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p6.id, data: () => p6 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part6", {
      topicIds: ["travel-1"],
      volumes: [],
    } as never);

    expect(result).toBeNull();
  });

  it("does not return a part5 exercise when requesting type part6, even though both share the same ToeicFilters shape", async () => {
    const p5 = makePart5Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] } });
    const p6 = makePart6Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: p5.id, data: () => p5 },
        { id: p6.id, data: () => p6 },
      ],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part6", {
      topicIds: ["biz-1"],
      volumes: ["vol3"],
    } as never);

    expect(result?.type).toBe("part6");
    expect(result?.id).toBe(p6.id);
  });
});

describe("getAllUsedVocabIds", () => {
  it("unions vocabIds across every saved bilingual exercise", async () => {
    const exA = makeBilingualExercise({ id: "a", passage: { sentences: [], vocabIds: ["v1", "v2"] } });
    const exB = makeBilingualExercise({ id: "b", passage: { sentences: [], vocabIds: ["v2", "v3"] } });
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

  it("skips a non-bilingual document instead of throwing on its missing passage.vocabIds shape", async () => {
    const p5 = makePart5Exercise();
    const bilingual = makeBilingualExercise({ id: "b", passage: { sentences: [], vocabIds: ["v1"] } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: p5.id, data: () => p5 },
        { id: bilingual.id, data: () => bilingual },
      ],
    } as never);

    const result = await getAllUsedVocabIds("user-123");

    expect(result).toEqual(new Set(["v1"]));
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
