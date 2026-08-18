import { describe, expect, it } from "vitest";
import {
  findKnownHeadwords,
  buildVocabSuggestionsPrompt,
  parseVocabSuggestions,
} from "./vocabSuggestions";
import type { VocabRecord } from "./vocabRecords";

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

describe("findKnownHeadwords", () => {
  it("returns headwords that appear in the text, case-insensitively", () => {
    const records = [
      makeRecord({ headword: "meticulous" }),
      makeRecord({ headword: "ephemeral" }),
    ];
    const known = findKnownHeadwords("She is very Meticulous about details.", records);
    expect(known).toEqual(["meticulous"]);
  });

  it("returns an empty array when no known headword appears in the text", () => {
    const records = [makeRecord({ headword: "meticulous" })];
    expect(findKnownHeadwords("A short unrelated sentence.", records)).toEqual([]);
  });

  it("deduplicates a headword that appears multiple times in the text", () => {
    const records = [makeRecord({ headword: "detail" })];
    const known = findKnownHeadwords("Every detail matters, down to the smallest detail.", records);
    expect(known).toEqual(["detail"]);
  });
});

describe("buildVocabSuggestionsPrompt", () => {
  it("includes the text, target language label, and asks for up to 10 suggestions in JSON", () => {
    const prompt = buildVocabSuggestionsPrompt("Some passage text.", "english", []);
    expect(prompt).toContain("Some passage text.");
    expect(prompt).toContain("English");
    expect(prompt).toContain("up to 10");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"suggestions"');
  });

  it("tells the AI which headwords to exclude when some are already known", () => {
    const prompt = buildVocabSuggestionsPrompt("text", "english", ["meticulous", "ephemeral"]);
    expect(prompt).toContain("Do NOT suggest any of these already-known words: meticulous, ephemeral.");
  });

  it("omits the exclusion clause entirely when nothing is already known", () => {
    const prompt = buildVocabSuggestionsPrompt("text", "english", []);
    expect(prompt).not.toContain("Do NOT suggest");
  });
});

describe("parseVocabSuggestions", () => {
  it("parses a full WordPhraseResult per suggestion", () => {
    const json = {
      suggestions: [
        {
          headword: "meticulous",
          ipa: "/məˈtɪkjələs/",
          meaning: "tỉ mỉ",
          definition: "showing great attention to detail",
          examples: ["She is meticulous."],
          synonyms: ["thorough"],
          suggestedTopics: ["Academic"],
          cefrLevel: "C1",
        },
      ],
    };

    const result = parseVocabSuggestions(json);

    expect(result).toEqual([
      {
        kind: "wordPhrase",
        headword: "meticulous",
        inputType: "word",
        ipa: "/məˈtɪkjələs/",
        meaning: "tỉ mỉ",
        examples: ["She is meticulous."],
        definition: "showing great attention to detail",
        synonyms: ["thorough"],
        suggestedTopics: ["Academic"],
        cefrLevel: "c1",
      },
    ]);
  });

  it("skips a suggestion item with no headword instead of throwing", () => {
    const result = parseVocabSuggestions({ suggestions: [{ meaning: "no headword here" }] });
    expect(result).toEqual([]);
  });

  it("returns an empty array when suggestions is missing or not an array", () => {
    expect(parseVocabSuggestions({})).toEqual([]);
    expect(parseVocabSuggestions({ suggestions: "not an array" })).toEqual([]);
  });
});
