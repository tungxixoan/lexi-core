import { describe, expect, it } from "vitest";
import { buildReadingPassagePrompt, parseReadingPassage, highlightVocabWords } from "./readingPassage";
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

  it("prompt tells the model to use natural sentence-position capitalization", () => {
    const prompt = buildReadingPassagePrompt(["Report", "Follow up"], "english", null);
    expect(prompt).toMatch(/natural .*capitali[sz]ation/i);
    expect(prompt).not.toMatch(/exactly as given/);
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

  it("normalizes smart typography in target and vietnamese", () => {
    const passage = parseReadingPassage(
      { sentences: [{ target: "It\u2019s \u201Cok\u201D.", vietnamese: "\u201CT\u1ed1t\u201D\u2026", vocabWords: [] }] },
      []
    );
    expect(passage.sentences[0].target).toBe('It\'s "ok".');
    expect(passage.sentences[0].vietnamese).toBe('"Tốt"...');
  });
});

describe("highlightVocabWords", () => {
  it("returns the whole text as one unhighlighted segment when there are no vocab words", () => {
    expect(highlightVocabWords("She is meticulous.", [])).toEqual([
      { text: "She is meticulous.", highlighted: false },
    ]);
  });

  it("splits the text into plain/highlighted segments around a single vocab word", () => {
    expect(highlightVocabWords("She is meticulous today.", ["meticulous"])).toEqual([
      { text: "She is ", highlighted: false },
      { text: "meticulous", highlighted: true },
      { text: " today.", highlighted: false },
    ]);
  });

  it("highlights multiple distinct vocab words in one sentence", () => {
    expect(highlightVocabWords("The ephemeral beauty was meticulous.", ["meticulous", "ephemeral"])).toEqual([
      { text: "The ", highlighted: false },
      { text: "ephemeral", highlighted: true },
      { text: " beauty was ", highlighted: false },
      { text: "meticulous", highlighted: true },
      { text: ".", highlighted: false },
    ]);
  });

  it("matches whole words only, not a vocab word as a substring of a longer word", () => {
    // "cat" must not highlight inside "category"
    expect(highlightVocabWords("This category is cat-themed.", ["cat"])).toEqual([
      { text: "This category is ", highlighted: false },
      { text: "cat", highlighted: true },
      { text: "-themed.", highlighted: false },
    ]);
  });

  it("matches multi-word phrases and is case-insensitive", () => {
    expect(highlightVocabWords("Let's touch base tomorrow.", ["Touch Base"])).toEqual([
      { text: "Let's ", highlighted: false },
      { text: "touch base", highlighted: true },
      { text: " tomorrow.", highlighted: false },
    ]);
  });

  it("prefers the longer vocab word when one is a substring of another", () => {
    // "base" alone shouldn't split "touch base" if both are given as vocab words
    expect(highlightVocabWords("Let's touch base soon.", ["base", "touch base"])).toEqual([
      { text: "Let's ", highlighted: false },
      { text: "touch base", highlighted: true },
      { text: " soon.", highlighted: false },
    ]);
  });

  it("escapes regex special characters in vocab words instead of treating them as regex syntax", () => {
    // Unescaped, the two "." in "a.k.a" would behave as regex wildcards
    // (harmless here, but proves the escape path runs without throwing
    // and still produces exact, not merely wildcard-coincidental, segments).
    expect(highlightVocabWords("It's known as a.k.a Bob.", ["a.k.a"])).toEqual([
      { text: "It's known as ", highlighted: false },
      { text: "a.k.a", highlighted: true },
      { text: " Bob.", highlighted: false },
    ]);
  });
});
