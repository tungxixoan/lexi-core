import { describe, expect, it } from "vitest";
import { normalizeTypography } from "./normalizeTypography";

describe("normalizeTypography", () => {
  it("straightens curly single quotes and apostrophes", () => {
    expect(normalizeTypography("it\u2019s \u2018here\u2019")).toBe("it's 'here'");
  });
  it("straightens curly double quotes and guillemets", () => {
    expect(normalizeTypography("\u201Cquote\u201D \u00ABx\u00BB")).toBe('"quote" "x"');
  });
  it("expands the ellipsis character to three dots", () => {
    expect(normalizeTypography("wait\u2026")).toBe("wait...");
  });
  it("collapses en/em/other dashes to a hyphen", () => {
    expect(normalizeTypography("a \u2013 b \u2014 c")).toBe("a - b - c");
  });
  it("replaces non-breaking, thin, and narrow spaces with a regular space", () => {
    expect(normalizeTypography("a\u00A0b\u2009c\u202Fd")).toBe("a b c d");
  });
  it("straightens prime and double-prime", () => {
    expect(normalizeTypography("5\u2032 6\u2033")).toBe("5' 6\"");
  });
  it("leaves plain ASCII untouched", () => {
    expect(normalizeTypography("The cat sat. It's 5-6 \"ok\".")).toBe('The cat sat. It\'s 5-6 "ok".');
  });
  it("returns an empty string unchanged", () => {
    expect(normalizeTypography("")).toBe("");
  });
});
