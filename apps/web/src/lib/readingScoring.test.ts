import { describe, expect, it } from "vitest";
import { computeSentenceStats, aggregateSentenceStats } from "./readingScoring";

describe("computeSentenceStats", () => {
  it("counts every character as correct when typed exactly matches target", () => {
    const stats = computeSentenceStats("Hello world.", "Hello world.", 0, 5000);
    expect(stats).toEqual({ correctChars: 12, totalChars: 12, deletedChars: 0, durationMs: 5000 });
  });

  it("counts only index-wise matching characters as correct when there's a mistake", () => {
    // "Hxllo world." vs "Hello world." — differs only at index 1
    const stats = computeSentenceStats("Hello world.", "Hxllo world.", 0, 5000);
    expect(stats.correctChars).toBe(11);
    expect(stats.totalChars).toBe(12);
  });

  it("passes through the caller-tracked deletedChars and durationMs unchanged", () => {
    const stats = computeSentenceStats("Hi.", "Hi.", 4, 9000);
    expect(stats.deletedChars).toBe(4);
    expect(stats.durationMs).toBe(9000);
  });
});

describe("aggregateSentenceStats", () => {
  it("computes 100% accuracy and finalScore for perfect typing with no deletions", () => {
    const result = aggregateSentenceStats([
      { correctChars: 12, totalChars: 12, deletedChars: 0, durationMs: 6000 },
    ]);
    expect(result.overallAccuracy).toBe(1);
    expect(result.deletionRatio).toBe(0);
    expect(result.finalScore).toBe(1);
  });

  it("computes wpm from total chars typed (5 chars = 1 word) and total duration", () => {
    // 60 chars / 5 = 12 words, over 60000ms = 1 minute -> 12 wpm
    const result = aggregateSentenceStats([
      { correctChars: 60, totalChars: 60, deletedChars: 0, durationMs: 60000 },
    ]);
    expect(result.wpm).toBe(12);
  });

  it("aggregates correctChars/totalChars/deletedChars/durationMs across multiple sentences", () => {
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 0, durationMs: 5000 },
      { correctChars: 8, totalChars: 10, deletedChars: 2, durationMs: 5000 },
    ]);
    expect(result.overallAccuracy).toBe(0.9); // 18/20
  });

  it("applies the deletion penalty: finalScore = accuracy - 0.5 * deletionRatio, clamped at 0", () => {
    // accuracy = 1 (typed correctly in the end), deletionRatio = 1 (deleted chars == total chars)
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 10, durationMs: 5000 },
    ]);
    expect(result.overallAccuracy).toBe(1);
    expect(result.deletionRatio).toBe(1);
    expect(result.finalScore).toBe(0.5);
  });

  it("clamps finalScore to a minimum of 0 when the deletion penalty would push it negative", () => {
    const result = aggregateSentenceStats([
      { correctChars: 2, totalChars: 10, deletedChars: 30, durationMs: 5000 },
    ]);
    expect(result.finalScore).toBe(0);
  });

  it("returns all-zero stats for an empty sentence list, with no division by zero", () => {
    const result = aggregateSentenceStats([]);
    expect(result).toEqual({ overallAccuracy: 0, deletionRatio: 0, finalScore: 0, wpm: 0 });
  });

  it("returns wpm 0 when total duration is 0, with no division by zero", () => {
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 0, durationMs: 0 },
    ]);
    expect(result.wpm).toBe(0);
  });
});
