import { describe, expect, it } from "vitest";
import { buildPart7Prompt, parsePart7Set, hasValidPart7Shape, type Part7Set } from "./part7";

describe("buildPart7Prompt", () => {
  it("includes topic names, target language label, and asks for exactly 3 passage groups in JSON", () => {
    const prompt = buildPart7Prompt(["Business"], "english", ["vol3"]);
    expect(prompt).toContain("Business");
    expect(prompt).toContain("English");
    expect(prompt).toContain("exactly 3 passage groups");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"passageGroups"');
  });

  it("joins multiple topic names with a slash", () => {
    const prompt = buildPart7Prompt(["Business", "Travel"], "english", ["vol3"]);
    expect(prompt).toContain("Business/Travel");
  });

  it("omits the register clause entirely when no topics are selected", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2"]);
    expect(prompt).not.toContain("register/setting");
  });

  it("requires the double-passage group to have exactly 5 questions and require both documents", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("exactly 5 multiple-choice questions");
    expect(prompt).toContain("requires information from both");
  });

  it("requires the two single-passage groups to use different document types", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("different document type than");
  });

  it("includes the prompt hint for every requested volume", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2", "vol4"]);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("unusual grammar/vocabulary traps");
  });

  it("uses every volume's hint when the volumes list is empty (matches Flutter's 'empty = all' default)", () => {
    const prompt = buildPart7Prompt([], "english", []);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("medium-high difficulty");
    expect(prompt).toContain("equal to or harder than the real exam");
    expect(prompt).toContain("deepest grammar traps");
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildPart7Prompt([], "korean", ["vol2"]);
    expect(prompt).toContain("한국어");
  });

  it("requires Vietnamese-script-only explanations", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parsePart7Set", () => {
  it("parses a full set of passage groups", () => {
    const json = {
      passageGroups: [
        {
          documents: ["Doc A"],
          questions: [{ question: "Q1?", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." }],
        },
      ],
    };

    const result = parsePart7Set(json);

    expect(result.passageGroups).toHaveLength(1);
    expect(result.passageGroups[0].documents).toEqual(["Doc A"]);
    expect(result.passageGroups[0].questions).toEqual([
      { question: "Q1?", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." },
    ]);
  });

  it("falls back to empty passageGroups when the response is missing fields", () => {
    const result = parsePart7Set({});
    expect(result).toEqual({ passageGroups: [] });
  });

  it("tolerates malformed question entries by defaulting their fields", () => {
    const result = parsePart7Set({ passageGroups: [{ documents: ["D"], questions: [{}] }] });
    expect(result.passageGroups[0].questions).toEqual([{ question: "", options: [], correctIndex: 0, explanation: "" }]);
  });

  it("defaults documents to an empty array when missing", () => {
    const result = parsePart7Set({ passageGroups: [{ questions: [] }] });
    expect(result.passageGroups[0].documents).toEqual([]);
  });

  it("ignores non-object entries in passageGroups and in a group's questions", () => {
    const result = parsePart7Set({
      passageGroups: ["not an object", { documents: ["D"], questions: ["also not an object", null] }],
    });
    expect(result.passageGroups).toEqual([{ documents: ["D"], questions: [] }]);
  });
});

describe("hasValidPart7Shape", () => {
  function makeQuestion(): Part7Set["passageGroups"][number]["questions"][number] {
    return { question: "Q", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E" };
  }

  function validSet(): Part7Set {
    return {
      passageGroups: [
        { documents: ["D1"], questions: [makeQuestion(), makeQuestion(), makeQuestion()] },
        { documents: ["D2"], questions: [makeQuestion(), makeQuestion(), makeQuestion(), makeQuestion()] },
        { documents: ["D3a", "D3b"], questions: Array.from({ length: 5 }, makeQuestion) },
      ],
    };
  }

  it("accepts a valid shape: 2 single-document groups (3-4 questions each) + 1 double-document group (5 questions)", () => {
    expect(hasValidPart7Shape(validSet())).toBe(true);
  });

  it("accepts 3 questions in a single-document group", () => {
    const set = validSet();
    set.passageGroups[1].questions = [makeQuestion(), makeQuestion(), makeQuestion()];
    expect(hasValidPart7Shape(set)).toBe(true);
  });

  it("rejects a set with fewer than 3 groups", () => {
    const set = validSet();
    set.passageGroups.pop();
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects a set with more than 3 groups", () => {
    const set = validSet();
    set.passageGroups.push(set.passageGroups[2]);
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when a single-document group actually has 2 documents", () => {
    const set = validSet();
    set.passageGroups[0].documents = ["D1", "D1b"];
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when a single-document group has only 2 questions", () => {
    const set = validSet();
    set.passageGroups[0].questions = set.passageGroups[0].questions.slice(0, 2);
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when a single-document group has 5 questions", () => {
    const set = validSet();
    set.passageGroups[0].questions = Array.from({ length: 5 }, makeQuestion);
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when the double-document group only has 1 document", () => {
    const set = validSet();
    set.passageGroups[2].documents = ["D3a"];
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when the double-document group doesn't have exactly 5 questions", () => {
    const set = validSet();
    set.passageGroups[2].questions = set.passageGroups[2].questions.slice(0, 4);
    expect(hasValidPart7Shape(set)).toBe(false);
  });
});
