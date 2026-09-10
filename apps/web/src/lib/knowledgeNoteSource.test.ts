import { describe, expect, it } from "vitest";
import { buildKnowledgeNotePrompt, parseKnowledgeNoteDraft } from "./knowledgeNoteSource";

describe("buildKnowledgeNotePrompt", () => {
  it("includes the language's group ids, the existing notes, Vietnamese + markup rules, JSON shape", () => {
    const p = buildKnowledgeNotePrompt({
      request: "giải thích loại 2",
      targetLanguage: "english",
      existingInScope: [{ id: "n9", title: "Loại 3", summary: "..." }],
    });
    expect(p).toContain("en_conditionals");
    expect(p).toContain("n9");
    expect(p).toContain("Vietnamese");
    expect(p).toContain("**");
    expect(p).toContain('"relatedNoteId"');
  });

  it("adds the merge clause only when extendingNote is set", () => {
    const base = buildKnowledgeNotePrompt({ request: "x", targetLanguage: "english", existingInScope: [] });
    expect(base).not.toContain("REVISING");
  });
});

describe("parseKnowledgeNoteDraft", () => {
  it("parses a well-formed draft", () => {
    const d = parseKnowledgeNoteDraft(
      {
        title: "T",
        summary: "S",
        explanation: "E",
        patterns: ["p"],
        examples: [{ text: "a", translation: "b" }],
        pitfalls: [],
        suggestedGroupId: "en_conditionals",
        suggestedCefr: "b1",
        suggestedTags: ["x"],
        relatedNoteId: null,
      },
      "english",
    );
    expect(d.suggestedGroupId).toBe("en_conditionals");
    expect(d.suggestedCefr).toBe("b1");
  });

  it("a hallucinated groupId falls back to en_other", () => {
    expect(
      parseKnowledgeNoteDraft({ title: "T", summary: "S", explanation: "E", suggestedGroupId: "en_bogus" }, "english")
        .suggestedGroupId,
    ).toBe("en_other");
  });

  it("missing optionals default safely; empty-string relatedNoteId → null", () => {
    const d = parseKnowledgeNoteDraft({ title: "T", summary: "S", explanation: "E", relatedNoteId: "" }, "english");
    expect(d.patterns).toEqual([]);
    expect(d.suggestedGroupId).toBeNull();
    expect(d.suggestedCefr).toBeNull();
    expect(d.relatedNoteId).toBeNull();
  });
});
