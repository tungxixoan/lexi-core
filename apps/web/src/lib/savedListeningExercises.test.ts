import { describe, expect, it, vi } from "vitest";
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { saveListeningExercise, getRandomSavedListeningExercise } from "./savedListeningExercises";
import type { DictationItem } from "./dictation";
import { parseListeningPassage } from "./listeningPassage";

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

const ITEM: DictationItem = {
  target: "I ate an apple today.",
  vietnamese: "Hôm nay tôi đã ăn một quả táo.",
  vocabIds: ["v1"],
};

function makeExercise(overrides: Partial<{ id: string; difficulty: "easy" | "medium" | "hard" }> = {}) {
  return {
    id: overrides.id ?? "ex-1",
    type: "dictation" as const,
    item: ITEM,
    generationFilters: { difficulty: overrides.difficulty ?? "hard" },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
  };
}

describe("saveListeningExercise", () => {
  it("creates a document carrying its own id field, and returns that id", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-id" } as never);

    const newId = await saveListeningExercise("user-123", "dictation", ITEM, { difficulty: "medium" }, "english");

    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-id" },
      expect.objectContaining({
        id: "new-id",
        type: "dictation",
        item: ITEM,
        generationFilters: { difficulty: "medium" },
        targetLanguage: "english",
      })
    );
    expect(newId).toBe("new-id");
  });
});

describe("getRandomSavedListeningExercise", () => {
  it("returns a saved exercise whose difficulty exactly matches the requested filter", async () => {
    const ex = makeExercise({ difficulty: "easy" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", "dictation", { difficulty: "easy" });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match a saved exercise with a different difficulty", async () => {
    const ex = makeExercise({ difficulty: "hard" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", "dictation", { difficulty: "easy" });

    expect(result).toBeNull();
  });

  it("returns null when nothing matches", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", "dictation", { difficulty: "hard" });

    expect(result).toBeNull();
  });

  it("excludes the given id from candidates", async () => {
    const ex = makeExercise({ id: "just-saved", difficulty: "hard" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedListeningExercise(
      "user-123",
      "english",
      "dictation",
      { difficulty: "hard" },
      "just-saved"
    );

    expect(result).toBeNull();
  });

  it("queries only documents matching the requested target language", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    await getRandomSavedListeningExercise("user-123", "english", "dictation", { difficulty: "hard" });

    expect(where).toHaveBeenCalledWith("targetLanguage", "==", "english");
  });
});

const COMPREHENSION_ITEM = parseListeningPassage(
  {
    kind: "talk",
    turns: [{ speaker: null, gender: "male", text: "Welcome aboard." }],
    questions: [{ question: "q", options: ["a", "b", "c", "d"], correctIndex: 0 }],
  },
  "b1",
  "general",
  "english"
);

describe("saveListeningExercise (comprehension)", () => {
  it("saves a comprehension exercise with its own filters shape, including speakerGenders", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-comprehension-id" } as never);

    const item = {
      kind: COMPREHENSION_ITEM.kind,
      turns: COMPREHENSION_ITEM.turns,
      questions: COMPREHENSION_ITEM.questions,
      speakerGenders: COMPREHENSION_ITEM.speakerGenders,
    };

    const newId = await saveListeningExercise("user-123", "comprehension", item, { context: "general", level: "b1" }, "english");

    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-comprehension-id" },
      expect.objectContaining({
        id: "new-comprehension-id",
        type: "comprehension",
        item: expect.objectContaining({
          speakerGenders: expect.objectContaining({ solo: "male" }),
        }),
        generationFilters: { context: "general", level: "b1" },
        targetLanguage: "english",
      })
    );
    expect(newId).toBe("new-comprehension-id");
  });
});

describe("getRandomSavedListeningExercise (comprehension) — level filter", () => {
  function makeComprehensionDoc(overrides: Partial<{ id: string; context: "general" | "business"; level: "b1" | "c1" }> = {}) {
    return {
      id: overrides.id ?? "comp-1",
      type: "comprehension" as const,
      item: {
        kind: COMPREHENSION_ITEM.kind,
        turns: COMPREHENSION_ITEM.turns,
        questions: COMPREHENSION_ITEM.questions,
        speakerGenders: COMPREHENSION_ITEM.speakerGenders,
      },
      generationFilters: { context: overrides.context ?? "general", level: overrides.level ?? "c1" },
      targetLanguage: "english" as const,
      createdAt: "2026-01-01T00:00:00.000Z",
    };
  }

  it("matches a saved exercise at ANY level when the filter's level is null ('Tất cả')", async () => {
    const doc = makeComprehensionDoc({ level: "c1" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: doc.id, data: () => doc }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", "comprehension", {
      context: "general",
      level: null,
    });

    expect(result?.id).toBe(doc.id);
  });

  it("does not match a saved exercise at a different level when the filter's level is a concrete level", async () => {
    const doc = makeComprehensionDoc({ level: "c1" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: doc.id, data: () => doc }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", "comprehension", {
      context: "general",
      level: "b1",
    });

    expect(result).toBeNull();
  });
});

describe("getRandomSavedListeningExercise (comprehension) — does not cross-match dictation docs", () => {
  it("never returns a dictation-typed doc when asking for comprehension, even with an identical-looking filter shape", async () => {
    // Regression guard mirroring savedReadingExercises.test.ts's own
    // cross-type test ("never returns a document of a different type..."):
    // seed a doc of the OTHER type whose generationFilters shape would
    // trivially satisfy matchesComprehension's context/level check if the
    // `ex.type !== type` guard were ever removed, then assert it's excluded.
    const dictationDoc = {
      id: "dict-1",
      type: "dictation" as const,
      item: ITEM,
      // Deliberately comprehension-shaped filters on a dictation-typed doc:
      // this is what makes the guard load-bearing rather than the filter
      // comparison itself.
      generationFilters: { context: "general", level: "b1" } as never,
      targetLanguage: "english" as const,
      createdAt: "2026-01-01T00:00:00.000Z",
    };
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: dictationDoc.id, data: () => dictationDoc }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", "comprehension", {
      context: "general",
      level: "b1",
    });

    expect(result).toBeNull();
  });
});
