import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { BoldText } from "./BoldText";

describe("BoldText", () => {
  it("renders one <p> per paragraph", () => {
    const { container } = render(<BoldText source={"para **one**\n\npara two"} />);
    expect(container.querySelectorAll("p")).toHaveLength(2);
  });
  it("wraps bold runs in <strong>", () => {
    render(<BoldText source={"a **b** c"} />);
    expect(screen.getByText("b").tagName).toBe("STRONG");
  });
  it("renders nothing meaningful for empty source", () => {
    const { container } = render(<BoldText source="" />);
    expect(container.querySelectorAll("p")).toHaveLength(0);
  });
});
