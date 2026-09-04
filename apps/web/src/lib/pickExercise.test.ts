import { describe, expect, it } from "vitest";
import { shouldUseFlashcard } from "./pickExercise";

describe("shouldUseFlashcard", () => {
  it("returns true for a never-reviewed word even with AI available", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 0 }, true, () => 0.9)).toBe(true);
  });

  it("returns true when no AI key is available", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 5 }, false, () => 0.9)).toBe(true);
  });

  it("returns true for a reviewed word when the roll lands under 0.30", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, () => 0.2)).toBe(true);
  });

  it("returns false for a reviewed word when the roll lands at/above 0.30", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, () => 0.5)).toBe(false);
  });

  it("boundary: exactly 0.30 is not a flashcard", () => {
    expect(shouldUseFlashcard({ sm2Repetitions: 3 }, true, () => 0.3)).toBe(false);
  });
});
