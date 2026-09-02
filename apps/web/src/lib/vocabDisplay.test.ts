import { describe, expect, it } from "vitest";
import {
  capitalizeHeadword,
  computeMasteryPercent,
  formatDueLabel,
  resolveTopicNames,
} from "./vocabDisplay";
import type { Topic } from "./topics";

describe("computeMasteryPercent", () => {
  it("is 0% for a brand-new word (0 repetitions, default ease)", () => {
    expect(computeMasteryPercent({ sm2Repetitions: 0, sm2EaseFactor: 2.5 })).toBe(0);
  });

  it("is 100% at 6+ repetitions with the default (max) ease factor", () => {
    expect(computeMasteryPercent({ sm2Repetitions: 6, sm2EaseFactor: 2.5 })).toBe(100);
    expect(computeMasteryPercent({ sm2Repetitions: 9, sm2EaseFactor: 2.5 })).toBe(100);
  });

  it("is 50% halfway through the repetitions ramp at max ease", () => {
    expect(computeMasteryPercent({ sm2Repetitions: 3, sm2EaseFactor: 2.5 })).toBe(50);
  });

  it("scales down when ease factor has dropped (many correct-but-difficult reviews)", () => {
    expect(computeMasteryPercent({ sm2Repetitions: 6, sm2EaseFactor: 1.3 })).toBe(52);
  });
});

describe("formatDueLabel", () => {
  const now = new Date("2026-08-15T12:00:00.000Z");

  it("shows 'chưa ôn' when the word has never been reviewed", () => {
    expect(formatDueLabel(null, now)).toBe("chưa ôn");
  });

  it("shows 'ôn hôm nay' when the review date is today or in the past", () => {
    expect(formatDueLabel("2026-08-15T00:00:00.000Z", now)).toBe("ôn hôm nay");
    expect(formatDueLabel("2026-08-10T00:00:00.000Z", now)).toBe("ôn hôm nay");
  });

  it("shows the day count when the review date is in the future", () => {
    expect(formatDueLabel("2026-08-18T12:00:00.000Z", now)).toBe("ôn sau 3 ngày");
  });
});

describe("resolveTopicNames", () => {
  const topics: Topic[] = [
    { id: "business", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
    { id: "academic", name: "Academic", emoji: "🎓", isPredefined: true, createdAt: "2026-01-01" },
  ];

  it("maps known topic ids to their names", () => {
    expect(resolveTopicNames(["business", "academic"], topics)).toEqual(["Business", "Academic"]);
  });

  it("falls back to the raw id for an unknown topic", () => {
    expect(resolveTopicNames(["ghost-id"], topics)).toEqual(["ghost-id"]);
  });
});

describe("capitalizeHeadword", () => {
  it.each([
    ["follow up", "Follow up"],
    ["Follow up", "Follow up"],
    ["TOEIC", "TOEIC"],
    ["iPhone", "IPhone"],
    ["3D printing", "3D printing"],
    ["đẹp", "Đẹp"], // "đẹp" -> "Đẹp"
    ["", ""],
  ])("capitalizeHeadword(%j) === %j", (input, expected) => {
    expect(capitalizeHeadword(input)).toBe(expected);
  });
});
