import { describe, expect, it, vi, beforeEach } from "vitest";
import { getDocs, setDoc, deleteDoc } from "firebase/firestore";
import {
  parseKnowledgeNote,
  getKnowledgeNotes,
  upsertKnowledgeNote,
  deleteKnowledgeNote,
  seedStartersIfNeeded,
  restoreStarters,
  type KnowledgeNote,
} from "./knowledgeNotes";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "col"),
  doc: vi.fn((...args: unknown[]) => ({ id: args[args.length - 1] ?? "generated-id" })),
  getDoc: vi.fn(),
  getDocs: vi.fn(),
  setDoc: vi.fn(),
  deleteDoc: vi.fn(),
  query: vi.fn(() => "q"),
  where: vi.fn(() => "w"),
  Timestamp: class {
    constructor(private ms: number) {}
    toDate() {
      return new Date(this.ms);
    }
  },
}));
vi.mock("@/lib/firebase", () => ({ getFirebaseDb: vi.fn(() => "db") }));

const note = (over: Partial<KnowledgeNote> = {}): KnowledgeNote => ({
  id: "n1",
  title: "T",
  summary: "s",
  explanation: "e",
  patterns: [],
  examples: [],
  pitfalls: [],
  groupId: "en_other",
  tags: [],
  cefrLevel: null,
  targetLanguage: "english",
  source: "manual",
  sourcePrompt: null,
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z",
  ...over,
});

function snap(docs: KnowledgeNote[]) {
  return { docs: docs.map((d) => ({ id: d.id, data: () => d })) };
}

beforeEach(() => vi.clearAllMocks());

describe("parseKnowledgeNote", () => {
  it("defends against missing arrays / unknown enums / a Timestamp date", async () => {
    const { Timestamp } = await import("firebase/firestore");
    const parsed = parseKnowledgeNote({
      id: "n2",
      title: "t",
      summary: "s",
      explanation: "e",
      groupId: "en_other",
      targetLanguage: "english",
      source: "weird",
      cefrLevel: "zz",
      createdAt: new (Timestamp as unknown as { new (n: number): unknown })(0),
      updatedAt: 1_700_000_000_000,
    });
    expect(parsed.patterns).toEqual([]);
    expect(parsed.examples).toEqual([]);
    expect(parsed.source).toBe("manual");
    expect(parsed.cefrLevel).toBeNull();
    expect(typeof parsed.createdAt).toBe("string");
    expect(typeof parsed.updatedAt).toBe("string");
  });

  it("null date → epoch string, does not throw", () => {
    const p = parseKnowledgeNote({
      id: "n",
      title: "t",
      summary: "",
      explanation: "",
      groupId: "en_other",
      targetLanguage: "english",
      source: "manual",
      cefrLevel: null,
      createdAt: null,
      updatedAt: null,
    });
    expect(p.createdAt).toBe(new Date(0).toISOString());
  });

  it("an unrecognised object date value THROWS (distinct from the null fallback)", () => {
    expect(() =>
      parseKnowledgeNote({
        id: "n",
        title: "t",
        summary: "",
        explanation: "",
        groupId: "en_other",
        targetLanguage: "english",
        source: "manual",
        createdAt: {},
      }),
    ).toThrow();
  });
});

describe("getKnowledgeNotes", () => {
  it("filters by language and sorts updatedAt desc", async () => {
    vi.mocked(getDocs).mockResolvedValue(
      snap([
        note({ id: "old", updatedAt: "2026-01-01T00:00:00.000Z" }),
        note({ id: "new", updatedAt: "2026-06-01T00:00:00.000Z" }),
        note({ id: "zh", targetLanguage: "chinese" }),
      ]) as never,
    );
    const out = await getKnowledgeNotes("u", "english");
    expect(out.map((n) => n.id)).toEqual(["new", "old"]);
  });

  it("skips an undecodable doc, keeps the rest; returns [] on a getDocs throw", async () => {
    vi.mocked(getDocs).mockResolvedValueOnce({
      docs: [
        { id: "bad", data: () => ({ examples: "not-a-list", createdAt: {} }) },
        { id: "good", data: () => note({ id: "good" }) },
      ],
    } as never);
    const out = await getKnowledgeNotes("u", "english");
    expect(out.map((n) => n.id)).toEqual(["good"]);

    vi.mocked(getDocs).mockRejectedValueOnce(new Error("offline"));
    expect(await getKnowledgeNotes("u", "english")).toEqual([]);
  });
});

describe("writes throw", () => {
  it("upsert rejects when setDoc rejects", async () => {
    vi.mocked(setDoc).mockRejectedValueOnce(new Error("permission-denied"));
    await expect(upsertKnowledgeNote("u", note())).rejects.toThrow("permission-denied");
  });

  it("delete rejects when deleteDoc rejects", async () => {
    vi.mocked(deleteDoc).mockRejectedValueOnce(new Error("nope"));
    await expect(deleteKnowledgeNote("u", "n1")).rejects.toThrow("nope");
  });
});

describe("seeding", () => {
  it("seeds once, respects the flag, does not seed a non-empty language", async () => {
    const { getDoc } = await import("firebase/firestore");
    vi.mocked(getDoc).mockResolvedValue({ data: () => ({}) } as never); // flag not set
    vi.mocked(getDocs).mockResolvedValue(snap([]) as never); // empty collection
    const wrote = await seedStartersIfNeeded("u", "english", [note({ id: "starter_en_x" })]);
    expect(wrote.map((n) => n.id)).toEqual(["starter_en_x"]);

    vi.mocked(getDoc).mockResolvedValue({ data: () => ({ english: true }) } as never);
    expect(await seedStartersIfNeeded("u", "english", [note({ id: "starter_en_x" })])).toEqual([]);
  });

  it("restoreStarters writes only absent ids", async () => {
    vi.mocked(getDocs).mockResolvedValue(snap([note({ id: "starter_en_a", title: "EDIT" })]) as never);
    const wrote = await restoreStarters("u", "english", [
      note({ id: "starter_en_a" }),
      note({ id: "starter_en_b" }),
    ]);
    expect(wrote.map((n) => n.id)).toEqual(["starter_en_b"]);
  });
});
