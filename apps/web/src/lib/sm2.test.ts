import { describe, expect, it } from "vitest";
import { computeSm2 } from "./sm2";

const NOW = new Date("2026-08-16T12:00:00.000Z");

describe("computeSm2", () => {
  it("resets repetitions and schedules tomorrow when quality is below 3, leaving ease factor unchanged", () => {
    const result = computeSm2({ sm2Repetitions: 4, sm2EaseFactor: 2.3, sm2Interval: 12 }, 1, NOW);
    expect(result.sm2Repetitions).toBe(0);
    expect(result.sm2Interval).toBe(1);
    expect(result.sm2EaseFactor).toBe(2.3);
    expect(result.nextReviewAt).toBe("2026-08-17T12:00:00.000Z");
    expect(result.updatedAt).toBe("2026-08-16T12:00:00.000Z");
  });

  it("uses a 1-day interval for the first successful repetition", () => {
    const result = computeSm2({ sm2Repetitions: 0, sm2EaseFactor: 2.5, sm2Interval: 1 }, 5, NOW);
    expect(result.sm2Repetitions).toBe(1);
    expect(result.sm2Interval).toBe(1);
    expect(result.nextReviewAt).toBe("2026-08-17T12:00:00.000Z");
  });

  it("uses a 6-day interval for the second successful repetition", () => {
    const result = computeSm2({ sm2Repetitions: 1, sm2EaseFactor: 2.5, sm2Interval: 1 }, 5, NOW);
    expect(result.sm2Repetitions).toBe(2);
    expect(result.sm2Interval).toBe(6);
    expect(result.nextReviewAt).toBe("2026-08-22T12:00:00.000Z");
  });

  it("uses interval × easeFactor, rounded, for the third and later repetitions", () => {
    const result = computeSm2({ sm2Repetitions: 2, sm2EaseFactor: 2.0, sm2Interval: 6 }, 5, NOW);
    expect(result.sm2Repetitions).toBe(3);
    expect(result.sm2Interval).toBe(12); // round(6 * 2.0)
  });

  it("increases ease factor for quality 5, clamped at the 2.5 maximum", () => {
    const result = computeSm2({ sm2Repetitions: 2, sm2EaseFactor: 2.5, sm2Interval: 6 }, 5, NOW);
    expect(result.sm2EaseFactor).toBe(2.5); // 2.5 + 0.1 - 0 = 2.6, clamped down to 2.5
  });

  it("decreases ease factor for a barely-passing quality 3, clamped at the 1.3 minimum", () => {
    const result = computeSm2({ sm2Repetitions: 2, sm2EaseFactor: 1.3, sm2Interval: 6 }, 3, NOW);
    expect(result.sm2EaseFactor).toBe(1.3); // 1.3 + 0.1 - 0.16 = 1.24, clamped up to 1.3
  });

  it("matches the exact quality-4 ease-factor formula with no clamping needed", () => {
    const result = computeSm2({ sm2Repetitions: 2, sm2EaseFactor: 2.0, sm2Interval: 6 }, 4, NOW);
    expect(result.sm2EaseFactor).toBeCloseTo(2.02, 5); // 2.0 + 0.1 - (5-4)*0.08 = 2.02
  });

  it("defaults `now` to the current time when omitted", () => {
    const before = Date.now();
    const result = computeSm2({ sm2Repetitions: 0, sm2EaseFactor: 2.5, sm2Interval: 1 }, 5);
    const after = Date.now();
    const updatedAtMs = new Date(result.updatedAt).getTime();
    expect(updatedAtMs).toBeGreaterThanOrEqual(before);
    expect(updatedAtMs).toBeLessThanOrEqual(after);
  });
});
