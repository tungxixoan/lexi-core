import { describe, expect, it } from "vitest";
import { formatPassageLines } from "./formatPassageText";

describe("formatPassageLines", () => {
  it("strips markdown bold markers", () => {
    expect(formatPassageLines("**Subject:** Update")).toEqual(["Subject: Update"]);
  });

  it("strips markdown headers", () => {
    expect(formatPassageLines("# Heading\nBody text")).toEqual(["Heading", "Body text"]);
  });

  it("normalizes bullet markers into a plain bullet dot", () => {
    expect(formatPassageLines("* First item\n- Second item")).toEqual(["• First item", "• Second item"]);
  });

  it("splits on newlines into separate lines", () => {
    expect(formatPassageLines("Line one\nLine two\nLine three")).toEqual(["Line one", "Line two", "Line three"]);
  });

  it("collapses multiple consecutive newlines and drops empty lines", () => {
    expect(formatPassageLines("Line one\n\n\nLine two")).toEqual(["Line one", "Line two"]);
  });

  it("returns the whole text as one line when there are no newlines", () => {
    expect(formatPassageLines("A single unbroken paragraph.")).toEqual(["A single unbroken paragraph."]);
  });

  it("trims leading/trailing whitespace from each line", () => {
    expect(formatPassageLines("  Line one  \n  Line two  ")).toEqual(["Line one", "Line two"]);
  });
});
