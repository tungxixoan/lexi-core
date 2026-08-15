import { describe, expect, it } from "vitest";
import { getPageWindow } from "./pageWindow";

describe("getPageWindow", () => {
  it("windows around a middle page with ellipses on both sides", () => {
    expect(getPageWindow(6, 29)).toEqual([1, "…", 4, 5, 6, 7, 8, "…", 29]);
  });

  it("has no leading ellipsis when near the first page", () => {
    expect(getPageWindow(1, 29)).toEqual([1, 2, 3, "…", 29]);
  });

  it("has no trailing ellipsis when near the last page", () => {
    expect(getPageWindow(29, 29)).toEqual([1, "…", 27, 28, 29]);
  });

  it("has no ellipses at all when every page already fits in the window", () => {
    expect(getPageWindow(1, 3)).toEqual([1, 2, 3]);
    expect(getPageWindow(2, 5)).toEqual([1, 2, 3, 4, 5]);
  });

  it("returns just [1] for a single page", () => {
    expect(getPageWindow(1, 1)).toEqual([1]);
  });
});
