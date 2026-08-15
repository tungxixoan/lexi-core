import { describe, expect, it, vi } from "vitest";
import { deleteDoc, doc, getDocs, orderBy, query, updateDoc } from "firebase/firestore";
import { countVocabRecords, deleteVocabRecord, getVocabRecords, updateVocabRecord } from "./vocabRecords";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  doc: vi.fn(() => "mock-doc-ref"),
  deleteDoc: vi.fn(),
  updateDoc: vi.fn(),
  getDocs: vi.fn(),
  orderBy: vi.fn(() => "mock-order-by"),
  query: vi.fn(() => "mock-query"),
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

const RECORD = {
  id: "abc",
  headword: "meticulous",
  inputType: "word",
  ipa: "/məˈtɪkjələs/",
  meaning: "tỉ mỉ, cẩn thận",
  examples: ["She reviewed the contract with meticulous attention to detail."],
  personalNotes: "",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "c1",
  activeContext: "business",
  createdAt: "2026-08-10T00:00:00.000Z",
  updatedAt: "2026-08-10T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 0,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

describe("getVocabRecords", () => {
  it("queries the subcollection ordered by createdAt desc and returns the raw docs", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      docs: [{ id: RECORD.id, data: () => RECORD }],
    } as never);

    const records = await getVocabRecords("user-123");

    expect(orderBy).toHaveBeenCalledWith("createdAt", "desc");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-order-by");
    expect(records).toEqual([RECORD]);
  });

  it("uses the Firestore snapshot document id, not the id field inside the document data", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        {
          id: "real-doc-id",
          data: () => ({ ...RECORD, id: "stale-field-id" }),
        },
      ],
    } as never);

    const records = await getVocabRecords("user-123");

    expect(records[0].id).toBe("real-doc-id");
  });
});

describe("deleteVocabRecord", () => {
  it("deletes the record document by id", async () => {
    await deleteVocabRecord("user-123", "abc");
    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records", "abc");
    expect(deleteDoc).toHaveBeenCalledWith("mock-doc-ref");
  });
});

describe("updateVocabRecord", () => {
  it("updates the editable fields plus updatedAt, by document id", async () => {
    await updateVocabRecord("user-123", "abc", {
      meaning: "nghĩa mới",
      examples: ["ví dụ mới"],
      topicIds: ["business"],
      personalNotes: "ghi chú",
    });

    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records", "abc");
    expect(updateDoc).toHaveBeenCalledWith(
      "mock-doc-ref",
      expect.objectContaining({
        meaning: "nghĩa mới",
        examples: ["ví dụ mới"],
        topicIds: ["business"],
        personalNotes: "ghi chú",
        updatedAt: expect.any(String),
      })
    );
  });
});
