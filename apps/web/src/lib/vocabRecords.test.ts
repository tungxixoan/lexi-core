import { describe, expect, it, vi } from "vitest";
import { getDocs } from "firebase/firestore";
import { countVocabRecords } from "./vocabRecords";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  getDocs: vi.fn(),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

describe("countVocabRecords", () => {
  it("returns the number of documents in the user's vocab_records subcollection", async () => {
    vi.mocked(getDocs).mockResolvedValue({ size: 3 } as never);
    const count = await countVocabRecords("user-123");
    expect(count).toBe(3);
  });
});
