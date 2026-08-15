import { describe, expect, it } from "vitest";
import RootLayout, { metadata } from "./layout";

describe("RootLayout", () => {
  it("renders html/body wrapping the given children without throwing on the bloom.css import", () => {
    const element = RootLayout({ children: <p>child</p> });
    expect(element.type).toBe("html");
    expect(element.props.lang).toBe("vi");
    expect(element.props.children.type).toBe("body");
    expect(element.props.children.props.children).toEqual(<p>child</p>);
  });

  it("sets the app metadata", () => {
    expect(metadata.title).toBe("LexiCore");
    expect(metadata.description).toBe("Personal Vietnamese-first language-learning app");
  });
});
