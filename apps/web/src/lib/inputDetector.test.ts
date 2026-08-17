import { describe, expect, it } from "vitest";
import { detectInputType } from "./inputDetector";

describe("detectInputType", () => {
  it("detects a single word", () => {
    expect(detectInputType("meticulous")).toBe("word");
  });

  it("detects a short phrase (2-4 words)", () => {
    expect(detectInputType("break the ice")).toBe("phrase");
    expect(detectInputType("a piece of cake")).toBe("phrase");
  });

  it("detects a sentence by terminal punctuation, regardless of word count", () => {
    expect(detectInputType("Hi.")).toBe("sentence");
    expect(detectInputType("Is this correct?")).toBe("sentence");
    expect(detectInputType("Wow!")).toBe("sentence");
  });

  it("detects a sentence by word count alone (more than 4 words, no punctuation)", () => {
    expect(detectInputType("she reviewed the contract carefully")).toBe("sentence");
  });

  it("treats empty or whitespace-only input as a word", () => {
    expect(detectInputType("")).toBe("word");
    expect(detectInputType("   ")).toBe("word");
  });
});
