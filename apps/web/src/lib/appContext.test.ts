import { describe, expect, it } from "vitest";
import { APP_CONTEXTS, APP_CONTEXT_LABELS, APP_CONTEXT_EMOJI } from "./appContext";

describe("appContext", () => {
  it("defines exactly the 8 contexts, matching VocabRecord's activeContext union", () => {
    expect(APP_CONTEXTS).toEqual([
      "general",
      "business",
      "technology",
      "travel",
      "foodAndDrink",
      "health",
      "academic",
      "socialCasual",
    ]);
  });

  it("has a label and emoji for every context", () => {
    for (const ctx of APP_CONTEXTS) {
      expect(APP_CONTEXT_LABELS[ctx]).toBeTruthy();
      expect(APP_CONTEXT_EMOJI[ctx]).toBeTruthy();
    }
  });
});
