import { describe, expect, it } from "vitest";
import {
  buildDictationPrompt,
  parseDictationItem,
  selectDictationBlanks,
  prioritizeDueWords,
  targetWords,
  targetTextForBlank,
  normalizeForComparison,
  isBlankCorrect,
  charAccuracy,
  blockAccuracy,
  seekPenaltyFraction,
  computeDictationScore,
  sm2QualityFromScore,
  type BlankSpan,
} from "./dictation";
import type { VocabRecord } from "./vocabRecords";

describe("buildDictationPrompt", () => {
  it("includes the target language label, the word list, and asks for one 10-18-word sentence in JSON", () => {
    const prompt = buildDictationPrompt(["apple", "run"], "english");
    expect(prompt).toContain("English");
    expect(prompt).toContain("apple, run");
    expect(prompt).toContain("10 to 18 words");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"target"');
    expect(prompt).toContain('"vocabWords"');
  });

  it("requires Vietnamese-script-only translations", () => {
    const prompt = buildDictationPrompt(["apple"], "english");
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parseDictationItem", () => {
  it("parses a full response and resolves vocabWords to vocabIds via the word map", () => {
    const json = { target: "I ate an apple.", vietnamese: "Tôi đã ăn một quả táo.", vocabWords: ["apple"] };
    const wordMap = { apple: "id-1", run: "id-2" };

    const result = parseDictationItem(json, wordMap);

    expect(result).toEqual({ target: "I ate an apple.", vietnamese: "Tôi đã ăn một quả táo.", vocabIds: ["id-1"] });
  });

  it("falls back to empty fields when the response is missing data", () => {
    expect(parseDictationItem({}, {})).toEqual({ target: "", vietnamese: "", vocabIds: [] });
  });

  it("drops any vocabWords entry that isn't in the word map", () => {
    const json = { target: "T", vietnamese: "V", vocabWords: ["apple", "unknown"] };
    expect(parseDictationItem(json, { apple: "id-1" }).vocabIds).toEqual(["id-1"]);
  });
});

describe("selectDictationBlanks", () => {
  it("hard difficulty returns no blanks", () => {
    expect(selectDictationBlanks("The quick brown fox jumps.", "hard")).toEqual([]);
  });

  it("easy difficulty on a single-word sentence returns one 1-word blank at index 0", () => {
    expect(selectDictationBlanks("Hello", "easy")).toEqual([{ startWordIndex: 0, wordCount: 1 }]);
  });

  it("easy difficulty returns exactly 2 single-word blanks", () => {
    const blanks = selectDictationBlanks("The quick brown fox jumps over the lazy dog", "easy", () => 0.5);
    expect(blanks).toHaveLength(2);
    for (const b of blanks) expect(b.wordCount).toBe(1);
  });

  it("easy difficulty enforces non-adjacent blanks once the sentence has 6+ words", () => {
    // 9 words -> enforceNonAdjacent, minIndex=1, maxIndex=7, range=7.
    // A deterministic random sequence that would naturally pick the same
    // index twice in a row exercises the retry loop.
    let call = 0;
    const sequence = [0, 0, 0.5];
    const random = () => sequence[Math.min(call++, sequence.length - 1)];
    const blanks = selectDictationBlanks("The quick brown fox jumps over the lazy dog", "easy", random);
    expect(blanks).toHaveLength(2);
    expect(Math.abs(blanks[1].startWordIndex - blanks[0].startWordIndex)).toBeGreaterThanOrEqual(2);
  });

  it("medium difficulty on a 3-or-fewer-word sentence blanks the whole sentence", () => {
    expect(selectDictationBlanks("Hi there", "medium")).toEqual([{ startWordIndex: 0, wordCount: 2 }]);
  });

  it("medium difficulty returns one span covering roughly 35% of the words, clamped to [2, wordCount-2]", () => {
    // 10 words -> spanLength = round(10*0.35) = 4 (already within [2, 8]).
    const blanks = selectDictationBlanks("one two three four five six seven eight nine ten", "medium", () => 0.5);
    expect(blanks).toHaveLength(1);
    expect(blanks[0].wordCount).toBe(4);
    expect(blanks[0].startWordIndex).toBeGreaterThanOrEqual(1);
    expect(blanks[0].startWordIndex + blanks[0].wordCount).toBeLessThanOrEqual(10);
  });
});

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

describe("prioritizeDueWords", () => {
  it("puts every due word ahead of every not-due word", () => {
    const now = new Date("2026-06-01T00:00:00.000Z");
    const due = makeRecord({ id: "due-1", nextReviewAt: null });
    const notDue = makeRecord({ id: "notdue-1", nextReviewAt: "2027-01-01T00:00:00.000Z" });
    const result = prioritizeDueWords([notDue, due], now);
    expect(result.map((r) => r.id)).toEqual(["due-1", "notdue-1"]);
  });

  it("keeps all records when everything is due, and all when nothing is due", () => {
    const now = new Date("2026-06-01T00:00:00.000Z");
    const allDue = [makeRecord({ id: "a", nextReviewAt: null }), makeRecord({ id: "b", nextReviewAt: null })];
    expect(prioritizeDueWords(allDue, now).map((r) => r.id).sort()).toEqual(["a", "b"]);
  });
});

describe("targetWords / targetTextForBlank", () => {
  it("splits on whitespace, dropping empty tokens", () => {
    expect(targetWords("The  quick brown")).toEqual(["The", "quick", "brown"]);
  });

  it("joins the words covered by a blank span with a single space", () => {
    const blank: BlankSpan = { startWordIndex: 1, wordCount: 2 };
    expect(targetTextForBlank("The quick brown fox", blank)).toBe("quick brown");
  });
});

describe("normalizeForComparison / isBlankCorrect", () => {
  it("lowercases, trims, collapses whitespace, and strips edge punctuation per word", () => {
    expect(normalizeForComparison("  Hello,   World!  ")).toBe("hello world");
  });

  it("treats an answer as correct when normalized forms match, ignoring case/punctuation/spacing", () => {
    const blank: BlankSpan = { startWordIndex: 0, wordCount: 1 };
    expect(isBlankCorrect("Apple is red.", blank, "  APPLE,  ")).toBe(true);
    expect(isBlankCorrect("Apple is red.", blank, "banana")).toBe(false);
  });
});

describe("charAccuracy", () => {
  it("is 1.0 for an exact match", () => {
    expect(charAccuracy("Hello.", "Hello.")).toBe(1);
  });

  it("counts only matching characters at the same index, over the target's full length", () => {
    // "Hxllo." vs "Hello." -> 5/6 correct.
    expect(charAccuracy("Hello.", "Hxllo.")).toBeCloseTo(5 / 6);
  });

  it("is 1.0 for an empty target (avoids division by zero)", () => {
    expect(charAccuracy("", "")).toBe(1);
  });
});

describe("blockAccuracy", () => {
  it("is 1.0 when there are no blanks", () => {
    expect(blockAccuracy("Hello world", [], [])).toBe(1);
  });

  it("is the fraction of blanks answered correctly", () => {
    const blanks: BlankSpan[] = [
      { startWordIndex: 0, wordCount: 1 },
      { startWordIndex: 1, wordCount: 1 },
    ];
    expect(blockAccuracy("Apple is red", blanks, ["apple", "wrong"])).toBe(0.5);
  });
});

describe("seekPenaltyFraction", () => {
  it("returns the minimum 0.01 when 20% or less of the sentence would be re-heard", () => {
    // 10 words, seeking to word 8 -> 2 words re-heard -> ratio 0.2.
    expect(seekPenaltyFraction(8, 10)).toBeCloseTo(0.01);
  });

  it("scales up to the maximum 0.05 when seeking back to the very start", () => {
    expect(seekPenaltyFraction(0, 10)).toBeCloseTo(0.05);
  });

  it("is 0 for a non-positive total word count", () => {
    expect(seekPenaltyFraction(0, 0)).toBe(0);
  });
});

describe("computeDictationScore", () => {
  it("hard difficulty uses charAccuracy as the raw score", () => {
    const score = computeDictationScore({
      difficulty: "hard",
      target: "Hello.",
      typed: "Hello.",
      blanks: [],
      blankAnswers: [],
      replayCount: 0,
      seekPenaltyTotal: 0,
    });
    expect(score).toBe(1);
  });

  it("non-hard difficulty uses blockAccuracy as the raw score, ignoring typed text", () => {
    const blanks: BlankSpan[] = [{ startWordIndex: 0, wordCount: 1 }];
    const score = computeDictationScore({
      difficulty: "easy",
      target: "Apple is red",
      typed: "",
      blanks,
      blankAnswers: ["apple"],
      replayCount: 0,
      seekPenaltyTotal: 0,
    });
    expect(score).toBe(1);
  });

  it("deducts 0.05 per replay and the full seekPenaltyTotal, clamped to [0, 1]", () => {
    const score = computeDictationScore({
      difficulty: "hard",
      target: "Hello.",
      typed: "Hello.",
      blanks: [],
      blankAnswers: [],
      replayCount: 3,
      seekPenaltyTotal: 0.06,
    });
    // 1.0 - 0.05*3 - 0.06 = 0.79
    expect(score).toBeCloseTo(0.79);
  });

  it("never goes below 0", () => {
    const score = computeDictationScore({
      difficulty: "hard",
      target: "Hello.",
      typed: "",
      blanks: [],
      blankAnswers: [],
      replayCount: 20,
      seekPenaltyTotal: 0,
    });
    expect(score).toBe(0);
  });
});

describe("sm2QualityFromScore", () => {
  it("maps score thresholds to the exact quality tiers Flutter uses (note: no tier '1' — jumps from 2 to 0)", () => {
    expect(sm2QualityFromScore(1.0)).toBe(5);
    expect(sm2QualityFromScore(0.95)).toBe(5);
    expect(sm2QualityFromScore(0.94)).toBe(4);
    expect(sm2QualityFromScore(0.80)).toBe(4);
    expect(sm2QualityFromScore(0.79)).toBe(3);
    expect(sm2QualityFromScore(0.60)).toBe(3);
    expect(sm2QualityFromScore(0.59)).toBe(2);
    expect(sm2QualityFromScore(0.40)).toBe(2);
    expect(sm2QualityFromScore(0.39)).toBe(0);
    expect(sm2QualityFromScore(0)).toBe(0);
  });
});
