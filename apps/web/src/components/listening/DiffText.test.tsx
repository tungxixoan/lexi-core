import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { DiffText } from "./DiffText";

describe("DiffText", () => {
  it("renders every typed character, marking each correct/wrong against the target at the same index", () => {
    render(<DiffText typed="Hxllo" target="Hello" />);

    const container = screen.getByTestId("diff-text");
    const spans = container.querySelectorAll("span");
    expect(spans).toHaveLength(5);
    expect(spans[0]).toHaveClass("diff-char-correct"); // H
    expect(spans[1]).toHaveClass("diff-char-wrong"); // x vs e
    expect(spans[2]).toHaveClass("diff-char-correct"); // l
    expect(container).toHaveTextContent("Hxllo");
  });

  it("marks a typed character beyond the target's length as wrong", () => {
    render(<DiffText typed="Hello!" target="Hello" />);

    const spans = screen.getByTestId("diff-text").querySelectorAll("span");
    expect(spans[5]).toHaveClass("diff-char-wrong"); // "!" has no counterpart in target
  });

  it("renders nothing extra when typed is shorter than target", () => {
    render(<DiffText typed="He" target="Hello" />);

    const spans = screen.getByTestId("diff-text").querySelectorAll("span");
    expect(spans).toHaveLength(2);
  });
});
