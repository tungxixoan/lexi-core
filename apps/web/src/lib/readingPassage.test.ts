import { describe, expect, it } from "vitest";
import { buildReadingPassagePrompt, parseReadingPassage } from "./readingPassage";
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

describe("buildReadingPassagePrompt", () => {
  it("includes every headword, the target language label, and asks for JSON only", () => {
    const prompt = buildReadingPassagePrompt(["meticulous", "ephemeral"], "english", null);
    expect(prompt).toContain("meticulous");
    expect(prompt).toContain("ephemeral");
    expect(prompt).toContain("English");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"sentences"');
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildReadingPassagePrompt(["안녕"], "korean", null);
    expect(prompt).toContain("한국어");
  });

  it("requires Vietnamese-script-only translations", () => {
    const prompt = buildReadingPassagePrompt(["word"], "english", null);
    expect(prompt).toContain("Vietnamese script");
  });

  it("tells the AI to cap difficulty at the given max CEFR level when one is set", () => {
    const prompt = buildReadingPassagePrompt(["word"], "english", "b1");
    expect(prompt).toContain("Keep the difficulty at or below CEFR level B1.");
  });

  it("omits the CEFR clause entirely when maxCefr is null", () => {
    const prompt = buildReadingPassagePrompt(["word"], "english", null);
    expect(prompt).not.toContain("CEFR level");
  });
});

describe("parseReadingPassage", () => {
  it("parses sentences and resolves vocabWords to vocab record ids via headword match", () => {
    const records = [
      makeRecord({ id: "id-1", headword: "meticulous" }),
      makeRecord({ id: "id-2", headword: "ephemeral" }),
    ];
    const json = {
      sentences: [
        { target: "She is meticulous.", vietnamese: "Cô ấy tỉ mỉ.", vocabWords: ["meticulous"] },
        {
          target: "Beauty is ephemeral.",
          vietnamese: "Vẻ đẹp phù du.",
          vocabWords: ["ephemeral"],
        },
      ],
    };

    const result = parseReadingPassage(json, records);

    expect(result.sentences).toEqual([
      { target: "She is meticulous.", vietnamese: "Cô ấy tỉ mỉ.", vocabWords: ["meticulous"] },
      { target: "Beauty is ephemeral.", vietnamese: "Vẻ đẹp phù du.", vocabWords: ["ephemeral"] },
    ]);
    expect(result.vocabIds.sort()).toEqual(["id-1", "id-2"]);
  });

  it("deduplicates vocabIds when the same word appears in multiple sentences", () => {
    const records = [makeRecord({ id: "id-1", headword: "meticulous" })];
    const json = {
      sentences: [
        { target: "She is meticulous.", vietnamese: "Cô ấy tỉ mỉ.", vocabWords: ["meticulous"] },
        {
          target: "He praised her meticulous work.",
          vietnamese: "Anh khen công việc tỉ mỉ của cô.",
          vocabWords: ["meticulous"],
        },
      ],
    };

    const result = parseReadingPassage(json, records);

    expect(result.vocabIds).toEqual(["id-1"]);
  });

  it("ignores a vocabWord that doesn't match any given record's headword (case-insensitive match)", () => {
    const records = [makeRecord({ id: "id-1", headword: "Meticulous" })];
    const json = {
      sentences: [
        {
          target: "She is meticulous but not punctual.",
          vietnamese: "Cô ấy tỉ mỉ nhưng không đúng giờ.",
          vocabWords: ["meticulous", "punctual"],
        },
      ],
    };

    const result = parseReadingPassage(json, records);

    expect(result.vocabIds).toEqual(["id-1"]);
    expect(result.sentences[0].vocabWords).toEqual(["meticulous", "punctual"]);
  });

  it("falls back to empty sentences and vocabIds when the AI response is missing fields", () => {
    const result = parseReadingPassage({}, []);
    expect(result).toEqual({ sentences: [], vocabIds: [] });
  });

  it("tolerates a sentence with missing vietnamese/vocabWords fields", () => {
    const result = parseReadingPassage(
      { sentences: [{ target: "Hello." }] },
      []
    );
    expect(result.sentences).toEqual([{ target: "Hello.", vietnamese: "", vocabWords: [] }]);
  });
});
