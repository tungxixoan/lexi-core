import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import HomePage from "./page";

describe("HomePage", () => {
  it("renders the LexiCore Web heading", () => {
    render(<HomePage />);
    expect(screen.getByRole("heading", { name: "LexiCore Web" })).toBeInTheDocument();
  });
});
