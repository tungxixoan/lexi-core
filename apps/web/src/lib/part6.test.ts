import { describe, expect, it } from "vitest";
import { buildPart6Prompt, parsePart6Set } from "./part6";

describe("buildPart6Prompt", () => {
  it("includes topic names, target language label, and asks for exactly 3 passages of 4 blanks each in JSON", () => {
    const prompt = buildPart6Prompt(["Business"], "english", ["vol3"]);
    expect(prompt).toContain("Business");
    expect(prompt).toContain("English");
    expect(prompt).toContain("exactly 3");
    expect(prompt).toContain("exactly 4");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"passages"');
  });

  it("joins multiple topic names with a slash", () => {
    const prompt = buildPart6Prompt(["Business", "Travel"], "english", ["vol3"]);
    expect(prompt).toContain("Business/Travel");
  });

  it("omits the register clause entirely when no topics are selected", () => {
    const prompt = buildPart6Prompt([], "english", ["vol2"]);
    expect(prompt).not.toContain("register/setting");
  });

  it("requires at least one 'select the best sentence' blank per passage", () => {
    const prompt = buildPart6Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("select the sentence that");
  });

  it("includes the prompt hint for every requested volume", () => {
    const prompt = buildPart6Prompt([], "english", ["vol2", "vol4"]);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("unusual grammar/vocabulary traps");
  });

  it("uses every volume's hint when the volumes list is empty (matches Flutter's 'empty = all' default)", () => {
    const prompt = buildPart6Prompt([], "english", []);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("medium-high difficulty");
    expect(prompt).toContain("equal to or harder than the real exam");
    expect(prompt).toContain("deepest grammar traps");
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildPart6Prompt([], "korean", ["vol2"]);
    expect(prompt).toContain("한국어");
  });

  it("requires Vietnamese-script-only explanations", () => {
    const prompt = buildPart6Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parsePart6Set", () => {
  it("parses a full set of passages", () => {
    const json = {
      passages: [
        {
          passageText: "... (1)___ ... (2)___ ... (3)___ ... (4)___ ...",
          questions: [
            { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." },
            { options: ["a", "b", "c", "d"], correctIndex: 1, explanation: "B." },
            { options: ["a", "b", "c", "d"], correctIndex: 2, explanation: "C." },
            { options: ["a", "b", "c", "d"], correctIndex: 3, explanation: "D." },
          ],
        },
      ],
    };

    const result = parsePart6Set(json);

    expect(result.passages).toHaveLength(1);
    expect(result.passages[0].passageText).toBe("... (1)___ ... (2)___ ... (3)___ ... (4)___ ...");
    expect(result.passages[0].questions).toHaveLength(4);
    expect(result.passages[0].questions[2]).toEqual({ options: ["a", "b", "c", "d"], correctIndex: 2, explanation: "C." });
  });

  it("falls back to empty passages when the response is missing fields", () => {
    const result = parsePart6Set({});
    expect(result).toEqual({ passages: [] });
  });

  it("drops a passage that doesn't have exactly 4 questions", () => {
    const json = {
      passages: [
        {
          passageText: "short one",
          questions: [{ options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." }],
        },
      ],
    };
    const result = parsePart6Set(json);
    expect(result.passages).toEqual([]);
  });

  it("tolerates malformed question entries by defaulting their fields, keeping the passage if it still has 4", () => {
    const result = parsePart6Set({
      passages: [{ passageText: "p", questions: [{}, {}, {}, {}] }],
    });
    expect(result.passages).toHaveLength(1);
    expect(result.passages[0].questions).toEqual([
      { options: [], correctIndex: 0, explanation: "" },
      { options: [], correctIndex: 0, explanation: "" },
      { options: [], correctIndex: 0, explanation: "" },
      { options: [], correctIndex: 0, explanation: "" },
    ]);
  });

  it("ignores non-object entries in the passages array", () => {
    const result = parsePart6Set({ passages: ["not an object", null, 42] });
    expect(result.passages).toEqual([]);
  });
});
