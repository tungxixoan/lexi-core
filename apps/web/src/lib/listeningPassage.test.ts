import { describe, expect, it } from "vitest";
import {
  buildListeningPassagePrompt,
  parseListeningPassage,
  assignVoices,
  scoreComprehension,
  type ListeningPassage,
} from "./listeningPassage";

describe("buildListeningPassagePrompt", () => {
  it("includes the level, context, and target language", () => {
    const prompt = buildListeningPassagePrompt("b1", "business", "english");
    expect(prompt).toContain("B1");
    expect(prompt).toContain("Business");
    expect(prompt).toContain("English");
  });

  it("instructs the AI to declare a gender per turn, consistent per speaker", () => {
    const prompt = buildListeningPassagePrompt("b1", "general", "english");
    expect(prompt).toContain("gender");
    expect(prompt).toMatch(/consistent/i);
  });

  it("requests exactly 3 multiple-choice questions with 4 options each", () => {
    const prompt = buildListeningPassagePrompt("b1", "general", "english");
    expect(prompt).toContain("3 multiple-choice questions");
    expect(prompt).toContain("4 answer options");
  });

  it("keeps A/B as structural speaker labels but forbids them in the dialogue and questions", () => {
    const prompt = buildListeningPassagePrompt("b1", "general", "english");
    // still asks for the structural label in the JSON shape
    expect(prompt).toContain('"speaker": "A" or "B" or null');
    // dialogue rule
    expect(prompt).toMatch(
      /never appear .*in any turn|must not use the letters "A"\/"B"|address each other by name/i
    );
    // question-reference rules: gender, then role, then first name
    expect(prompt).toMatch(/người đàn ông.*người phụ nữ/i);
    expect(prompt).toMatch(/role in the situation|khách hàng|nhân viên/i);
    expect(prompt).toContain("người nói");
  });
});

describe("parseListeningPassage", () => {
  const validJson = {
    kind: "conversation",
    turns: [
      { speaker: "A", gender: "male", text: "Hello, how can I help you?" },
      { speaker: "B", gender: "female", text: "I'm looking for a book." },
    ],
    questions: [
      { question: "What does B want?", options: ["A book", "A pen", "A map", "A ticket"], correctIndex: 0 },
    ],
  };

  it("parses a valid conversation", () => {
    const passage = parseListeningPassage(validJson, "b1", "general", "english");
    expect(passage.kind).toBe("conversation");
    expect(passage.turns).toHaveLength(2);
    expect(passage.questions).toHaveLength(1);
  });

  it("derives speakerGenders from each speaker's first-seen turn", () => {
    const passage = parseListeningPassage(validJson, "b1", "general", "english");
    expect(passage.speakerGenders).toEqual({ A: "male", B: "female" });
  });

  it("is defensive against a speaker's gender changing on a later turn — keeps the first-seen value", () => {
    const inconsistent = {
      ...validJson,
      turns: [
        { speaker: "A", gender: "male", text: "First." },
        { speaker: "A", gender: "female", text: "Same speaker, wrong gender this time." },
      ],
    };
    const passage = parseListeningPassage(inconsistent, "b1", "general", "english");
    expect(passage.speakerGenders.A).toBe("male");
  });

  it("defaults kind to 'talk' for anything other than the literal string 'conversation'", () => {
    const passage = parseListeningPassage({ ...validJson, kind: "something-else" }, "b1", "general", "english");
    expect(passage.kind).toBe("talk");
  });

  it("defaults missing/malformed fields to empty rather than throwing", () => {
    const passage = parseListeningPassage({}, "b1", "general", "english");
    expect(passage.turns).toEqual([]);
    expect(passage.questions).toEqual([]);
    expect(passage.speakerGenders).toEqual({});
  });
});

describe("assignVoices", () => {
  function passageWith(turns: { speaker: "A" | "B" | null; gender: "male" | "female" }[]): ListeningPassage {
    return {
      kind: turns.length > 1 && turns[0].speaker !== null ? "conversation" : "talk",
      turns: turns.map((t) => ({ speaker: t.speaker, text: "x" })),
      questions: [],
      speakerGenders: turns.reduce<Record<string, "male" | "female">>((acc, t) => {
        const key = t.speaker ?? "solo";
        if (!(key in acc)) acc[key] = t.gender;
        return acc;
      }, {}),
      level: "b1",
      context: "general",
      targetLanguage: "english",
    };
  }

  it("assigns exactly one voice for a talk (single speaker)", () => {
    const passage = passageWith([{ speaker: null, gender: "male" }]);
    const voices = assignVoices(passage);
    expect(voices.solo).toBe("male1");
  });

  it("assigns two distinct voices for a male-female conversation", () => {
    const passage = passageWith([
      { speaker: "A", gender: "male" },
      { speaker: "B", gender: "female" },
    ]);
    const voices = assignVoices(passage);
    expect(voices.A).toBe("male1");
    expect(voices.B).toBe("female1");
  });

  it("assigns two DISTINCT voices for a same-gender (male-male) conversation", () => {
    const passage = passageWith([
      { speaker: "A", gender: "male" },
      { speaker: "B", gender: "male" },
    ]);
    const voices = assignVoices(passage);
    expect(voices.A).toBe("male1");
    expect(voices.B).toBe("male2");
    expect(voices.A).not.toBe(voices.B);
  });

  it("assigns two DISTINCT voices for a same-gender (female-female) conversation", () => {
    const passage = passageWith([
      { speaker: "A", gender: "female" },
      { speaker: "B", gender: "female" },
    ]);
    const voices = assignVoices(passage);
    expect(voices.A).toBe("female1");
    expect(voices.B).toBe("female2");
    expect(voices.A).not.toBe(voices.B);
  });
});

describe("scoreComprehension", () => {
  const passage: ListeningPassage = {
    kind: "talk",
    turns: [],
    speakerGenders: {},
    level: "b1",
    context: "general",
    targetLanguage: "english",
    questions: [
      { question: "q1", options: ["a", "b", "c", "d"], correctIndex: 0 },
      { question: "q2", options: ["a", "b", "c", "d"], correctIndex: 1 },
      { question: "q3", options: ["a", "b", "c", "d"], correctIndex: 2 },
    ],
  };

  it("is 0 when nothing is answered", () => {
    expect(scoreComprehension(passage, [null, null, null])).toBe(0);
  });

  it("is 1/3 when only one answer is correct", () => {
    expect(scoreComprehension(passage, [0, null, null])).toBeCloseTo(1 / 3);
  });

  it("is 1.0 when every answer is correct", () => {
    expect(scoreComprehension(passage, [0, 1, 2])).toBe(1);
  });

  it("never counts a null (unanswered) entry as correct even if correctIndex happens to be 0", () => {
    expect(scoreComprehension(passage, [null, 1, 2])).toBeCloseTo(2 / 3);
  });
});
