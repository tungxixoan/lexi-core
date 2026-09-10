// @vitest-environment node
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { startersFor } from "./knowledgeStarters";
import { knowledgeGroupsFor } from "./knowledgeGroups";

describe("knowledgeStarters", () => {
  it("English → 12 parsed starter notes in valid groups", () => {
    const notes = startersFor("english");
    expect(notes).toHaveLength(12);
    const valid = new Set(knowledgeGroupsFor("english").map((g) => g.id));
    for (const n of notes) {
      expect(n.source).toBe("starter");
      expect(valid.has(n.groupId)).toBe(true);
      expect(n.examples.length).toBeGreaterThanOrEqual(2);
    }
    expect(new Set(notes.map((n) => n.id)).size).toBe(12);
  });

  it("non-English → []", () => {
    expect(startersFor("chinese")).toEqual([]);
    expect(startersFor("korean")).toEqual([]);
    expect(startersFor("japanese")).toEqual([]);
    expect(startersFor("vietnamese")).toEqual([]);
  });

  it("stays byte-identical to the Flutter source asset (drift guard)", () => {
    // From apps/web/src/lib/ the repo root is 4 levels up. `__dirname` is not
    // reliably defined in this Vitest/ESM setup, so resolve via
    // import.meta.url (repo pattern, see boldMarkup.test.ts / bloom.test.ts).
    const web = readFileSync(
      fileURLToPath(new URL("../data/knowledge/starter_en.json", import.meta.url)),
      "utf8",
    );
    const flutter = readFileSync(
      fileURLToPath(new URL("../../../../assets/knowledge/starter_en.json", import.meta.url)),
      "utf8",
    );
    expect(JSON.parse(web)).toEqual(JSON.parse(flutter));
  });
});
