import { describe, expect, it } from "vitest";
import { buildPart5Prompt, parsePart5Set } from "./part5";

describe("buildPart5Prompt", () => {
  it("includes topic names, target language label, and asks for exactly 15 questions in JSON", () => {
    const prompt = buildPart5Prompt(["Business"], "english", ["vol3"]);
    expect(prompt).toContain("Business");
    expect(prompt).toContain("English");
    expect(prompt).toContain("exactly 15");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"questions"');
  });

  it("joins multiple topic names with a slash", () => {
    const prompt = buildPart5Prompt(["Business", "Travel"], "english", ["vol3"]);
    expect(prompt).toContain("Business/Travel");
  });

  it("omits the register clause entirely when no topics are selected", () => {
    const prompt = buildPart5Prompt([], "english", ["vol2"]);
    expect(prompt).not.toContain("register/setting");
  });

  it("includes the prompt hint for every requested volume", () => {
    const prompt = buildPart5Prompt([], "english", ["vol2", "vol4"]);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("unusual grammar/vocabulary traps");
  });

  it("uses every volume's hint when the volumes list is empty (matches Flutter's 'empty = all' default)", () => {
    const prompt = buildPart5Prompt([], "english", []);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("medium-high difficulty");
    expect(prompt).toContain("equal to or harder than the real exam");
    expect(prompt).toContain("deepest grammar traps");
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildPart5Prompt([], "korean", ["vol2"]);
    expect(prompt).toContain("한국어");
  });

  it("requires Vietnamese-script-only explanations", () => {
    const prompt = buildPart5Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parsePart5Set", () => {
  it("parses a full set of questions", () => {
    const json = {
      questions: [
        { sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "Ngôi thứ ba số ít." },
      ],
    };

    const result = parsePart5Set(json);

    expect(result.questions).toEqual([
      { sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "Ngôi thứ ba số ít." },
    ]);
  });

  it("falls back to empty questions when the response is missing fields", () => {
    const result = parsePart5Set({});
    expect(result).toEqual({ questions: [] });
  });

  it("tolerates a malformed question entry by defaulting its fields", () => {
    const result = parsePart5Set({ questions: [{}] });
    expect(result.questions).toEqual([{ sentenceWithBlank: "", options: [], correctIndex: 0, explanation: "" }]);
  });

  it("ignores non-object entries in the questions array", () => {
    const result = parsePart5Set({ questions: ["not an object", null, 42] });
    expect(result.questions).toEqual([]);
  });
});
