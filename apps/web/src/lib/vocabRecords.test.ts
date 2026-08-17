import { describe, expect, it, vi } from "vitest";
import { deleteDoc, doc, getDocs, orderBy, query, setDoc, updateDoc, where } from "firebase/firestore";
import {
  countVocabRecords,
  deleteVocabRecord,
  getVocabRecordByHeadword,
  getVocabRecords,
  saveVocabRecord,
  updateVocabRecord,
  updateVocabRecordSm2,
  type VocabRecord,
} from "./vocabRecords";
import type { Sm2Fields } from "./sm2";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  doc: vi.fn(() => "mock-doc-ref"),
  deleteDoc: vi.fn(),
  updateDoc: vi.fn(),
  setDoc: vi.fn(),
  getDocs: vi.fn(),
  orderBy: vi.fn(() => "mock-order-by"),
  query: vi.fn(() => "mock-query"),
  where: vi.fn(() => "mock-where"),
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

const RECORD: VocabRecord = {
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

describe("getVocabRecordByHeadword", () => {
  it("queries by headword and targetLanguage, and returns null when nothing matches", async () => {
    vi.mocked(getDocs).mockResolvedValue({ empty: true, docs: [] } as never);

    const result = await getVocabRecordByHeadword("user-123", "meticulous", "english");

    expect(where).toHaveBeenCalledWith("headword", "==", "meticulous");
    expect(where).toHaveBeenCalledWith("targetLanguage", "==", "english");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-where", "mock-where");
    expect(result).toBeNull();
  });

  it("returns the first matching record with its real Firestore document id", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      empty: false,
      docs: [{ id: "real-doc-id", data: () => RECORD }],
    } as never);

    const result = await getVocabRecordByHeadword("user-123", "meticulous", "english");

    expect(result?.id).toBe("real-doc-id");
    expect(result?.headword).toBe("meticulous");
  });
});

describe("saveVocabRecord", () => {
  it("creates a new document with an auto-generated id and returns it", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-doc-id" } as never);
    const { id: _omit, ...newRecord } = RECORD;

    const newId = await saveVocabRecord("user-123", newRecord);

    expect(doc).toHaveBeenCalledWith("mock-collection-ref");
    expect(setDoc).toHaveBeenCalledWith({ id: "new-doc-id" }, { ...newRecord, id: "new-doc-id" });
    expect(newId).toBe("new-doc-id");
  });
});

describe("updateVocabRecordSm2", () => {
  it("writes exactly the SM-2 fields, by document id, with no updatedAt override of its own", async () => {
    // The saveVocabRecord test above overrides doc()'s mock return value
    // (via mockReturnValue, not mockReturnValueOnce) and this suite has no
    // afterEach/resetAllMocks, so it leaks into later tests. Restore the
    // shared default explicitly rather than relying on run order.
    vi.mocked(doc).mockReturnValue("mock-doc-ref" as never);

    const sm2Fields: Sm2Fields = {
      sm2Repetitions: 3,
      sm2EaseFactor: 2.4,
      sm2Interval: 12,
      nextReviewAt: "2026-08-28T12:00:00.000Z",
      updatedAt: "2026-08-16T12:00:00.000Z",
    };

    await updateVocabRecordSm2("user-123", "abc", sm2Fields);

    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records", "abc");
    expect(updateDoc).toHaveBeenCalledWith("mock-doc-ref", sm2Fields);
  });
});
