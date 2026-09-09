// @vitest-environment node
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { parseBoldMarkup, type TextRun } from "./boldMarkup";

// The SAME fixture the Flutter test uses (test/fixtures/bold_markup_vectors.json).
// From apps/web/src/lib/ the repo root is 4 levels up. `__dirname` is not reliably
// defined in this Vitest/ESM setup, so resolve via import.meta.url (repo pattern,
// see src/styles/bloom.test.ts).
const vectors = JSON.parse(
  readFileSync(
    fileURLToPath(
      new URL("../../../../test/fixtures/bold_markup_vectors.json", import.meta.url),
    ),
    "utf8",
  ),
) as { name: string; in: string; out: { t: string; b: boolean }[][] }[];

function toRuns(out: { t: string; b: boolean }[][]): TextRun[][] {
  return out.map((para) => para.map((r) => ({ text: r.t, bold: r.b })));
}

describe("parseBoldMarkup — shared vectors", () => {
  it("loads every shared fixture vector (guards a truncated/corrupted file)", () => {
    expect(vectors).toHaveLength(14);
  });

  for (const v of vectors) {
    it(`vector: ${v.name}`, () => {
      expect(parseBoldMarkup(v.in)).toEqual(toRuns(v.out));
    });
  }
});

describe("parseBoldMarkup — nested **", () => {
  it("treats an inner ** as a boundary (non-overlapping matches)", () => {
    // Deterministic split by /\*\*([^*]+?)\*\*/g: non-overlapping matches are
    // "**a **" (bold "a ") then "** c**" (bold " c"), leaving "b" between them as
    // a plain run. `[^*]+?` forbids `*` inside a span, so nesting cannot occur.
    // Matches the Flutter parser's behaviour (same regex, same non-overlapping
    // scan) — the rule is "defined behaviour", not a specific aesthetic.
    expect(parseBoldMarkup("**a **b** c**")).toEqual([
      [
        { text: "a ", bold: true },
        { text: "b", bold: false },
        { text: " c", bold: true },
      ],
    ]);
  });
});
