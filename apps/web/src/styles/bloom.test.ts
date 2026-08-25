// @vitest-environment node
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const css = readFileSync(fileURLToPath(new URL("./bloom.css", import.meta.url)), "utf-8");

describe("bloom.css design tokens", () => {
  it("defines the light-mode Bloom color tokens with exact values", () => {
    expect(css).toContain("--bg-a: #FFF3EE;");
    expect(css).toContain("--bg-b: #F1EEFF;");
    expect(css).toContain("--surface: #FFFFFF;");
    expect(css).toContain("--accent: #C9587A;");
    expect(css).toContain("--sage: #6F9A87;");
    expect(css).toContain("--danger: #C15B4E;");
    expect(css).toContain("--border: #EFDDE3;");
  });

  it("defines the dark-mode tokens under both a prefers-color-scheme block and a [data-theme=dark] block", () => {
    expect(css).toContain('@media (prefers-color-scheme: dark) {');
    expect(css).toContain(':root:not([data-theme="light"])');
    expect(css).toContain(':root[data-theme="dark"]');
    expect(css).toContain("--accent: #E693AC;");
  });

  it("sets the Bloom font stack on body with no external font import", () => {
    expect(css).toContain(
      'font-family: "Trebuchet MS", "Segoe UI", -apple-system, system-ui, sans-serif;'
    );
    expect(css).not.toContain("@import");
    expect(css).not.toContain("fonts.googleapis.com");
  });

  it("app-frame is borderless and edge-to-edge — no max-width cap, no rounded corners, no shadow", () => {
    // Decided permanent: the floating-card look (rounded corners + shadow +
    // max-width cap) was an experiment; the borderless, edge-to-edge frame
    // is the kept design.
    const frameBlock = css.match(/\.app-frame \{[^}]*\}/)?.[0] ?? "";
    expect(frameBlock).not.toContain("max-width");
    expect(frameBlock).toContain("border-radius: 0;");
    expect(frameBlock).toContain("border: none;");
    expect(frameBlock).toContain("box-shadow: none;");
  });
});
