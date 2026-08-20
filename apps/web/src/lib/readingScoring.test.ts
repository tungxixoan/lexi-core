import { describe, expect, it } from "vitest";
import { computeSentenceStats, aggregateSentenceStats, countMismatches } from "./readingScoring";

describe("countMismatches", () => {
  it("returns 0 when typed matches target exactly over the typed prefix", () => {
    expect(countMismatches("Hello world.", "Hello")).toBe(0);
  });

  it("counts index-wise mismatches only over the typed prefix, ignoring untyped tail", () => {
    // "Hxllo" vs "Hello world." — 1 mismatch at index 1, rest of target untyped
    expect(countMismatches("Hello world.", "Hxllo")).toBe(1);
  });

  it("counts multiple mismatches", () => {
    expect(countMismatches("Hello world.", "Hxllx")).toBe(2);
  });
});

describe("computeSentenceStats", () => {
  it("counts every character as correct when typed exactly matches target", () => {
    const stats = computeSentenceStats("Hello world.", "Hello world.", 0, 0, 5000);
    expect(stats).toEqual({
      correctChars: 12,
      totalChars: 12,
      deletedChars: 0,
      mistakeChars: 0,
      durationMs: 5000,
    });
  });

  it("counts only index-wise matching characters as correct when there's a mistake", () => {
    // "Hxllo world." vs "Hello world." — differs only at index 1
    const stats = computeSentenceStats("Hello world.", "Hxllo world.", 0, 0, 5000);
    expect(stats.correctChars).toBe(11);
    expect(stats.totalChars).toBe(12);
  });

  it("passes through the caller-tracked deletedChars, mistakeChars, and durationMs unchanged", () => {
    const stats = computeSentenceStats("Hi.", "Hi.", 4, 2, 9000);
    expect(stats.deletedChars).toBe(4);
    expect(stats.mistakeChars).toBe(2);
    expect(stats.durationMs).toBe(9000);
  });
});

describe("aggregateSentenceStats", () => {
  it("computes 100% accuracy and finalScore for perfect typing with no deletions", () => {
    const result = aggregateSentenceStats([
      { correctChars: 12, totalChars: 12, deletedChars: 0, mistakeChars: 0, durationMs: 6000 },
    ]);
    expect(result.overallAccuracy).toBe(1);
    expect(result.deletionRatio).toBe(0);
    expect(result.finalScore).toBe(1);
  });

  it("computes wpm from total chars typed (5 chars = 1 word) and total duration", () => {
    // 60 chars / 5 = 12 words, over 60000ms = 1 minute -> 12 wpm
    const result = aggregateSentenceStats([
      { correctChars: 60, totalChars: 60, deletedChars: 0, mistakeChars: 0, durationMs: 60000 },
    ]);
    expect(result.wpm).toBe(12);
  });

  it("aggregates correctChars/totalChars/deletedChars/durationMs across multiple sentences", () => {
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 0, mistakeChars: 0, durationMs: 5000 },
      { correctChars: 8, totalChars: 10, deletedChars: 2, mistakeChars: 0, durationMs: 5000 },
    ]);
    expect(result.overallAccuracy).toBe(0.9); // 18/20
  });

  it("applies the deletion penalty: finalScore = accuracy - 0.5 * deletionRatio, clamped at 0", () => {
    // accuracy = 1 (typed correctly in the end), deletionRatio = 1 (deleted chars == total chars)
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 10, mistakeChars: 0, durationMs: 5000 },
    ]);
    expect(result.overallAccuracy).toBe(1);
    expect(result.deletionRatio).toBe(1);
    expect(result.finalScore).toBe(0.5);
  });

  it("clamps finalScore to a minimum of 0 when the deletion penalty would push it negative", () => {
    const result = aggregateSentenceStats([
      { correctChars: 2, totalChars: 10, deletedChars: 30, mistakeChars: 0, durationMs: 5000 },
    ]);
    expect(result.finalScore).toBe(0);
  });

  it("clamps finalScore to a maximum of 1 when overallAccuracy alone would exceed 1", () => {
    // A malformed stat (correctChars > totalChars) shouldn't be possible from
    // computeSentenceStats, but aggregateSentenceStats accepts any
    // SentenceStats[] — the Math.min(1, ...) clamp must still engage.
    const result = aggregateSentenceStats([
      { correctChars: 15, totalChars: 10, deletedChars: 0, mistakeChars: 0, durationMs: 5000 },
    ]);
    expect(result.overallAccuracy).toBe(1.5);
    expect(result.finalScore).toBe(1);
  });

  it("returns all-zero stats for an empty sentence list, with no division by zero", () => {
    const result = aggregateSentenceStats([]);
    expect(result).toEqual({
      overallAccuracy: 0,
      typingAccuracy: 0,
      deletionRatio: 0,
      finalScore: 0,
      wpm: 0,
    });
  });

  it("returns wpm 0 when total duration is 0, with no division by zero", () => {
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 0, mistakeChars: 0, durationMs: 0 },
    ]);
    expect(result.wpm).toBe(0);
  });

  it("computes typingAccuracy as 1 minus the ratio of peak mistakes to total chars", () => {
    // 3 mistakeChars out of 10 totalChars -> 0.7, even though overallAccuracy is 1
    // (the sentence was typed correctly by the end — mistakeChars reflects what
    // happened along the way, not the final state)
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 3, mistakeChars: 3, durationMs: 5000 },
    ]);
    expect(result.overallAccuracy).toBe(1);
    expect(result.typingAccuracy).toBe(0.7);
  });

  it("clamps typingAccuracy to a minimum of 0 when mistakes exceed total chars", () => {
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 15, mistakeChars: 15, durationMs: 5000 },
    ]);
    expect(result.typingAccuracy).toBe(0);
  });

  it("aggregates mistakeChars across multiple sentences for typingAccuracy", () => {
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 1, mistakeChars: 1, durationMs: 5000 },
      { correctChars: 10, totalChars: 10, deletedChars: 1, mistakeChars: 3, durationMs: 5000 },
    ]);
    // 4 mistakeChars out of 20 totalChars -> 0.8
    expect(result.typingAccuracy).toBe(0.8);
  });
});
