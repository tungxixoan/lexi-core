import { describe, expect, it } from "vitest";
import { normalizeTypography } from "./normalizeTypography";

describe("normalizeTypography", () => {
  it("straightens curly single quotes and apostrophes", () => {
    expect(normalizeTypography(`it's 'here'`)).toBe(`it's 'here'`);
  });
  it("straightens curly double quotes and guillemets", () => {
    expect(normalizeTypography(`"quote" «x»`)).toBe(`"quote" "x"`);
  });
  it("expands the ellipsis character to three dots", () => {
    expect(normalizeTypography(`wait…`)).toBe(`wait...`);
  });
  it("collapses en/em/other dashes to a hyphen", () => {
    expect(normalizeTypography(`a – b — c`)).toBe(`a - b - c`);
  });
  it("replaces non-breaking and thin spaces with a regular space", () => {
    expect(normalizeTypography("a b c d")).toBe("a b c d");
  });
  it("straightens prime and double-prime", () => {
    expect(normalizeTypography(`5′ 6″`)).toBe(`5' 6"`);
  });
  it("leaves plain ASCII untouched", () => {
    expect(normalizeTypography(`The cat sat. It's 5-6 "ok".`)).toBe(`The cat sat. It's 5-6 "ok".`);
  });
  it("returns an empty string unchanged", () => {
    expect(normalizeTypography(``)).toBe(``);
  });
});
