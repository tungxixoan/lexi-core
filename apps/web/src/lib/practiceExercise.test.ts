import { beforeEach, describe, expect, it, vi } from "vitest";
import type { VocabRecord } from "./vocabRecords";

vi.mock("./generateContent", () => ({ generateContent: vi.fn() }));

import { generateContent } from "./generateContent";
import { buildExercisePrompt, generateExercise, parseExercise } from "./practiceExercise";

const generateContentMock = vi.mocked(generateContent);

function makeRecord(overrides: Partial<VocabRecord> = {}): VocabRecord {
  return {
    id: "id",
    headword: "ephemeral",
    inputType: "word",
    ipa: "",
    meaning: "chỉ tồn tại trong thời gian rất ngắn",
    examples: ["An ephemeral trend.", "Ephemeral beauty fades.", "A third example."],
    personalNotes: "",
    topicIds: [],
    targetLanguage: "english",
    cefrLevel: "b2",
    activeContext: "general",
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    nextReviewAt: null,
    sm2Repetitions: 3,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: "",
    synonyms: [],
    ...overrides,
  };
}

const AI = { provider: "gemini" as const, model: "gemini-2.0-flash", apiKeyCiphertext: "cipher" };

beforeEach(() => {
  generateContentMock.mockReset();
});

describe("buildExercisePrompt", () => {
  it("includes the headword, meaning, CEFR label, and the Vietnamese-script guard", () => {
    const prompt = buildExercisePrompt(makeRecord());
    expect(prompt).toContain("ephemeral");
    expect(prompt).toContain("chỉ tồn tại trong thời gian rất ngắn");
    expect(prompt).toContain("CEFR level: B2");
    expect(prompt).toContain("Vietnamese script");
  });

  it("uses the target-language display label and only the first two examples", () => {
    const prompt = buildExercisePrompt(makeRecord());
    expect(prompt).toContain("studying English.");
    expect(prompt).toContain('Examples: "An ephemeral trend.; Ephemeral beauty fades."');
    expect(prompt).not.toContain("A third example.");
  });
});

describe("parseExercise", () => {
  const record = makeRecord();

  it("maps a valid multiple_choice payload", () => {
    const ex = parseExercise(
      {
        type: "multiple_choice",
        question: "What does 'ephemeral' mean?",
        options: ["short-lived", "eternal", "loud", "green"],
        correctIndex: 0,
      },
      record
    );
    expect(ex).toEqual({
      type: "multiple_choice",
      record,
      question: "What does 'ephemeral' mean?",
      options: ["short-lived", "eternal", "loud", "green"],
      correctIndex: 0,
    });
  });

  it("normalizes fill_in_blank answers to lowercase + trimmed", () => {
    const ex = parseExercise(
      { type: "fill_in_blank", sentence: "The ___ moment passed.", answer: "  RUN  " },
      record
    );
    expect(ex).toEqual({
      type: "fill_in_blank",
      record,
      sentence: "The ___ moment passed.",
      answer: "run",
    });
  });

  it("maps a valid translation payload", () => {
    const ex = parseExercise(
      { type: "translation", prompt: "Translate to Vietnamese: 'It was ephemeral.'", answer: "Nó chỉ thoáng qua." },
      record
    );
    expect(ex).toEqual({
      type: "translation",
      record,
      prompt: "Translate to Vietnamese: 'It was ephemeral.'",
      answer: "Nó chỉ thoáng qua.",
    });
  });

  it("falls back to flashcard for an unknown type", () => {
    expect(parseExercise({ type: "foo" }, record)).toEqual({ type: "flashcard", record });
  });

  it("falls back to flashcard when multiple_choice is missing options (no throw)", () => {
    expect(parseExercise({ type: "multiple_choice", question: "x" }, record)).toEqual({
      type: "flashcard",
      record,
    });
  });

  it("falls back to flashcard when fill_in_blank is missing sentence + answer", () => {
    expect(parseExercise({ type: "fill_in_blank" }, record)).toEqual({ type: "flashcard", record });
  });
});

describe("generateExercise", () => {
  const record = makeRecord();

  it("returns a flashcard when generateContent rejects", async () => {
    generateContentMock.mockRejectedValue(new Error("network down"));
    const ex = await generateExercise(record, AI);
    expect(ex).toEqual({ type: "flashcard", record });
  });

  it("parses a valid multiple_choice JSON response", async () => {
    generateContentMock.mockResolvedValue({
      text: JSON.stringify({
        type: "multiple_choice",
        question: "What does 'ephemeral' mean?",
        options: ["short-lived", "eternal", "loud", "green"],
        correctIndex: 0,
      }),
    });
    const ex = await generateExercise(record, AI);
    expect(ex).toEqual({
      type: "multiple_choice",
      record,
      question: "What does 'ephemeral' mean?",
      options: ["short-lived", "eternal", "loud", "green"],
      correctIndex: 0,
    });
    expect(generateContentMock).toHaveBeenCalledWith({
      provider: "gemini",
      model: "gemini-2.0-flash",
      apiKeyCiphertext: "cipher",
      prompt: buildExercisePrompt(record),
    });
  });
});
