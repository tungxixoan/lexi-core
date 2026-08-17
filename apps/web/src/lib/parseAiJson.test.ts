import { describe, expect, it } from "vitest";
import { parseAiJsonObject } from "./parseAiJson";

describe("parseAiJsonObject", () => {
  it("parses a plain JSON object", () => {
    expect(parseAiJsonObject('{"a":1}')).toEqual({ a: 1 });
  });

  it("strips markdown code fences", () => {
    expect(parseAiJsonObject('```json\n{"a":1}\n```')).toEqual({ a: 1 });
    expect(parseAiJsonObject('```\n{"a":1}\n```')).toEqual({ a: 1 });
  });

  it("extracts a balanced JSON object even with trailing prose around it", () => {
    expect(parseAiJsonObject('Sure! {"a":1} Hope that helps.')).toEqual({ a: 1 });
  });

  it("does not get confused by braces inside string values", () => {
    expect(parseAiJsonObject('{"a":"contains { and } inside"}')).toEqual({
      a: "contains { and } inside",
    });
  });

  it("throws when no JSON object can be found", () => {
    expect(() => parseAiJsonObject("no json here")).toThrow();
  });
});
