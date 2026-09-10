import { describe, expect, it } from "vitest";
import { findRelatedNotes } from "./knowledgeDedup";
import type { KnowledgeNote } from "./knowledgeNotes";

const n = (over: Partial<KnowledgeNote>): KnowledgeNote => ({
  id: "x", title: "", summary: "", explanation: "", patterns: [], examples: [], pitfalls: [],
  groupId: "en_other", tags: [], cefrLevel: null, targetLanguage: "english",
  source: "manual", sourcePrompt: null, createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z", ...over,
});

describe("findRelatedNotes", () => {
  it("matches on a repeated phrase in the title", () => {
    const hits = findRelatedNotes({
      prompt: "giải thích câu điều kiện loại 2 khi nào dùng",
      notes: [n({ id: "a", title: "Câu điều kiện loại 2 và 3" }), n({ id: "b", title: "Mệnh đề quan hệ" })],
    });
    expect(hits.map((h) => h.id)).toEqual(["a"]);
  });
  it("matches cross-diacritic", () => {
    expect(findRelatedNotes({ prompt: "cau dieu kien loai 2", notes: [n({ id: "a", title: "Câu điều kiện loại 2" })] })
      .map((h) => h.id)).toEqual(["a"]);
  });
  it("tag exact match scores", () => {
    expect(findRelatedNotes({ prompt: "ôn toeic phần này", notes: [n({ id: "a", title: "Ghi chú", tags: ["toeic"] })] })
      .map((h) => h.id)).toEqual(["a"]);
  });
  it("thì / thể are content words (whole-branch fix)", () => {
    expect(findRelatedNotes({ prompt: "thì thể", notes: [n({ id: "a", title: "Thì thể" })] })
      .map((h) => h.id)).toEqual(["a"]);
  });
  it("below threshold → []", () => {
    expect(findRelatedNotes({ prompt: "hiện tại đơn", notes: [n({ id: "a", title: "Mệnh đề quan hệ" })] })).toEqual([]);
  });
  it("caps at 3, sorted by score desc", () => {
    const notes = ["hiện tại đơn", "hiện tại tiếp diễn", "hiện tại hoàn thành", "quá khứ đơn"]
      .map((t, i) => n({ id: String(i), title: t }));
    const hits = findRelatedNotes({ prompt: "hiện tại đơn giải thích", notes });
    expect(hits).toHaveLength(3);
    expect(hits[0].id).toBe("0");
  });
});
