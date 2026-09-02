import { describe, expect, it } from "vitest";
import { normalizeTopicName, preselectTopicIds, buildVocabRecordDraft } from "./vocabDraft";
import type { Topic } from "./topics";
import type { WordPhraseResult } from "./lookup";

const TOPICS: Topic[] = [
  { id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
  { id: "food-1", name: "Food & Drink", emoji: "🍜", isPredefined: true, createdAt: "2026-01-01" },
];

const TOPICS_WITH_OTHER: Topic[] = [
  ...TOPICS,
  { id: "other-1", name: "Other", emoji: "🏷️", isPredefined: true, createdAt: "2026-01-01" },
];

describe("normalizeTopicName", () => {
  it("lowercases, collapses punctuation, and treats & as and", () => {
    expect(normalizeTopicName("Food & Drink")).toBe("food and drink");
    expect(normalizeTopicName("food and drink")).toBe("food and drink");
  });
});

describe("preselectTopicIds", () => {
  it("matches suggested topic names case-insensitively, capped at 2, no duplicates", () => {
    expect(preselectTopicIds(["business", "Business", "food and drink"], TOPICS)).toEqual([
      "biz-1",
      "food-1",
    ]);
  });

  it("returns an empty array when no suggestion matches an existing topic and there's no Other topic", () => {
    expect(preselectTopicIds(["Sports"], TOPICS)).toEqual([]);
  });

  it("falls back to Other when no suggestion matches and an Other topic exists", () => {
    expect(preselectTopicIds(["Sports"], TOPICS_WITH_OTHER)).toEqual(["other-1"]);
  });

  it("falls back to Other when there are no suggested topics at all", () => {
    expect(preselectTopicIds([], TOPICS_WITH_OTHER)).toEqual(["other-1"]);
  });

  it("does not fall back to Other when a real suggestion already matched", () => {
    expect(preselectTopicIds(["Business"], TOPICS_WITH_OTHER)).toEqual(["biz-1"]);
  });
});

describe("buildVocabRecordDraft", () => {
  const RESULT: WordPhraseResult = {
    kind: "wordPhrase",
    headword: "meticulous",
    inputType: "word",
    ipa: "/məˈtɪkjələs/",
    meaning: "tỉ mỉ",
    examples: ["She is meticulous."],
    definition: "showing great attention to detail",
    synonyms: ["thorough"],
    suggestedTopics: ["Business"],
    cefrLevel: "c1",
  };

  it("builds a VocabRecord draft with an empty id, preselected topics, and general context", () => {
    const draft = buildVocabRecordDraft(RESULT, TOPICS, "english");

    expect(draft.id).toBe("");
    expect(draft.headword).toBe("Meticulous");
    expect(draft.meaning).toBe("tỉ mỉ");
    expect(draft.examples).toEqual(["She is meticulous."]);
    expect(draft.topicIds).toEqual(["biz-1"]);
    expect(draft.targetLanguage).toBe("english");
    expect(draft.cefrLevel).toBe("c1");
    expect(draft.activeContext).toBe("general");
    expect(draft.personalNotes).toBe("");
    expect(draft.nextReviewAt).toBeNull();
    expect(draft.sm2Repetitions).toBe(0);
    expect(draft.sm2EaseFactor).toBe(2.5);
    expect(draft.sm2Interval).toBe(1);
    expect(draft.definition).toBe("showing great attention to detail");
    expect(draft.synonyms).toEqual(["thorough"]);
  });

  it("defaults cefrLevel to b1 when the AI result has none", () => {
    const draft = buildVocabRecordDraft({ ...RESULT, cefrLevel: null }, TOPICS, "english");
    expect(draft.cefrLevel).toBe("b1");
  });

  it("capitalizes the first letter of the headword", () => {
    const draft = buildVocabRecordDraft(
      { ...RESULT, headword: "follow up" },
      [],
      "english"
    );
    expect(draft.headword).toBe("Follow up");
  });
});
