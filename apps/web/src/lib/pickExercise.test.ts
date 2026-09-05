import { describe, expect, it } from "vitest";
import { drawSessionAiRatio, shouldUseFlashcard } from "./pickExercise";

describe("shouldUseFlashcard", () => {
  it("returns true for a never-reviewed word even with AI available", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 0 }, true, 1, () => 0.99)).toBe(true);
  });

  it("returns true when no AI key is available", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 5 }, false, 1, () => 0.99)).toBe(true);
  });

  it("aiRatio 0 is always flashcard for an eligible word", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0, () => 0.99)).toBe(true);
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0, () => 0)).toBe(true);
  });

  it("aiRatio 1 is never flashcard for an eligible word", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 1, () => 0.99)).toBe(false);
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 1, () => 0)).toBe(false);
  });

  it("reproduces the historical 30/70 split at aiRatio 0.7", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0.7, () => 0.2)).toBe(true);
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0.7, () => 0.3)).toBe(false);
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0.7, () => 0.5)).toBe(false);
  });

  it("uses Math.random by default when rng is omitted", () => {
    // Just confirm it doesn't throw and returns a boolean when no rng is passed.
    expect(typeof shouldUseFlashcard({ sm2Repetitions: 3 }, true, 0.5)).toBe("boolean");
  });
});

describe("drawSessionAiRatio", () => {
  it("roll 0 maps to the low end of the range", () => {
    expect(drawSessionAiRatio(() => 0)).toBeCloseTo(0.2);
  });

  it("roll approaching 1 maps to the high end of the range", () => {
    expect(drawSessionAiRatio(() => 0.999999)).toBeLessThanOrEqual(0.8);
    expect(drawSessionAiRatio(() => 0.999999)).toBeGreaterThan(0.79);
  });

  it("roll 0.5 maps to the midpoint", () => {
    expect(drawSessionAiRatio(() => 0.5)).toBeCloseTo(0.5);
  });

  it("uses Math.random by default and stays within [0.20, 0.80]", () => {
    const r = drawSessionAiRatio();
    expect(r).toBeGreaterThanOrEqual(0.2);
    expect(r).toBeLessThan(0.8);
  });
});
