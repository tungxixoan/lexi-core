import { describe, expect, it } from "vitest";
import { normalizeForSearch } from "./normalizeSearch";

describe("normalizeForSearch", () => {
  it("folds Vietnamese diacritics and đ", () => {
    expect(normalizeForSearch("Câu điều kiện")).toBe("cau dieu kien");
    expect(normalizeForSearch("ĐIỀU")).toBe("dieu");
  });
  it("lowercases, strips punctuation to spaces, collapses whitespace", () => {
    expect(normalizeForSearch("Present  Perfect!!  (tense)")).toBe("present perfect tense");
  });
  it("empty / punctuation-only input", () => {
    expect(normalizeForSearch("   ")).toBe("");
    expect(normalizeForSearch("***")).toBe("");
  });
  it("keeps digits", () => {
    expect(normalizeForSearch("loại 2 và 3")).toBe("loai 2 va 3");
  });
});
