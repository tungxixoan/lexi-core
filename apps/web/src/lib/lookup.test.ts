import { describe, expect, it } from "vitest";
import { buildWordPhrasePrompt, buildSentencePrompt, parseLookupResult, type WordPhraseResult } from "./lookup";

describe("buildWordPhrasePrompt", () => {
  it("includes the query and target language label, and asks for JSON only", () => {
    const prompt = buildWordPhrasePrompt("meticulous", "english");
    expect(prompt).toContain('"meticulous"');
    expect(prompt).toContain("English");
    expect(prompt).toContain("JSON only");
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildWordPhrasePrompt("안녕", "korean");
    expect(prompt).toContain("한국어");
  });
});

describe("buildSentencePrompt", () => {
  it("includes the sentence and requires Vietnamese-script-only translation", () => {
    const prompt = buildSentencePrompt("Hello world.");
    expect(prompt).toContain('"Hello world."');
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parseLookupResult", () => {
  it("parses a word/phrase result, lowercasing the CEFR level", () => {
    const result = parseLookupResult(
      {
        headword: "meticulous",
        ipa: "/məˈtɪkjələs/",
        meaning: "tỉ mỉ, cẩn thận",
        definition: "Showing great attention to detail.",
        synonyms: ["thorough", "careful"],
        examples: ["She is meticulous."],
        suggestedTopics: ["Business"],
        cefrLevel: "C1",
      },
      "word",
      "meticulous"
    );
    expect(result).toEqual({
      kind: "wordPhrase",
      headword: "meticulous",
      inputType: "word",
      ipa: "/məˈtɪkjələs/",
      meaning: "tỉ mỉ, cẩn thận",
      examples: ["She is meticulous."],
      definition: "Showing great attention to detail.",
      synonyms: ["thorough", "careful"],
      suggestedTopics: ["Business"],
      cefrLevel: "c1",
    });
  });

  it("falls back to a null cefrLevel for a missing or invalid value, and to empty arrays for missing lists", () => {
    const result = parseLookupResult(
      { headword: "x", meaning: "y" },
      "word",
      "x"
    ) as WordPhraseResult;
    expect(result.cefrLevel).toBeNull();
    expect(result.examples).toEqual([]);
    expect(result.synonyms).toEqual([]);
    expect(result.suggestedTopics).toEqual([]);
  });

  it("falls back to the original query as headword when the AI omits it", () => {
    const result = parseLookupResult({ meaning: "y" }, "phrase", "break the ice") as WordPhraseResult;
    expect(result.headword).toBe("break the ice");
  });

  it("parses a sentence result using the original query, not anything from the AI response", () => {
    const result = parseLookupResult(
      { translation: "Xin chào thế giới." },
      "sentence",
      "Hello world."
    );
    expect(result).toEqual({
      kind: "sentence",
      original: "Hello world.",
      translation: "Xin chào thế giới.",
    });
  });
});
