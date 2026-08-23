import { describe, expect, it, vi } from "vitest";
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { saveListeningExercise, getRandomSavedListeningExercise } from "./savedListeningExercises";
import type { DictationItem } from "./dictation";

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

    const newId = await saveListeningExercise("user-123", ITEM, { difficulty: "medium" }, "english");

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

    const result = await getRandomSavedListeningExercise("user-123", "english", { difficulty: "easy" });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match a saved exercise with a different difficulty", async () => {
    const ex = makeExercise({ difficulty: "hard" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", { difficulty: "easy" });

    expect(result).toBeNull();
  });

  it("returns null when nothing matches", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", { difficulty: "hard" });

    expect(result).toBeNull();
  });

  it("excludes the given id from candidates", async () => {
    const ex = makeExercise({ id: "just-saved", difficulty: "hard" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", { difficulty: "hard" }, "just-saved");

    expect(result).toBeNull();
  });

  it("queries only documents matching the requested target language", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    await getRandomSavedListeningExercise("user-123", "english", { difficulty: "hard" });

    expect(where).toHaveBeenCalledWith("targetLanguage", "==", "english");
  });
});
