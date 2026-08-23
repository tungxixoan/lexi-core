import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { ClozeInput } from "./ClozeInput";

describe("ClozeInput", () => {
  it("renders visible words as plain text and blanks as labeled inputs, in order", () => {
    render(
      <ClozeInput
        target="The quick brown fox jumps"
        blanks={[{ startWordIndex: 1, wordCount: 1 }]}
        answers={[""]}
        onAnswerChange={vi.fn()}
      />
    );

    expect(screen.getByText(/^The/)).toBeInTheDocument();
    expect(screen.getByLabelText("Chỗ trống 1")).toBeInTheDocument();
    expect(screen.getByText(/brown fox jumps/)).toBeInTheDocument();
  });

  it("shows the current answer value in the blank's input", () => {
    render(
      <ClozeInput
        target="The quick brown fox"
        blanks={[{ startWordIndex: 1, wordCount: 1 }]}
        answers={["slow"]}
        onAnswerChange={vi.fn()}
      />
    );

    expect(screen.getByLabelText("Chỗ trống 1")).toHaveValue("slow");
  });

  it("calls onAnswerChange with the blank's index when its input changes", () => {
    const onAnswerChange = vi.fn();
    render(
      <ClozeInput
        target="The quick brown fox"
        blanks={[
          { startWordIndex: 0, wordCount: 1 },
          { startWordIndex: 2, wordCount: 1 },
        ]}
        answers={["", ""]}
        onAnswerChange={onAnswerChange}
      />
    );

    fireEvent.change(screen.getByLabelText("Chỗ trống 2"), { target: { value: "brown" } });

    expect(onAnswerChange).toHaveBeenCalledWith(1, "brown");
  });

  it("renders a blank at the very start of the sentence with no leading text", () => {
    render(
      <ClozeInput
        target="Hello world"
        blanks={[{ startWordIndex: 0, wordCount: 1 }]}
        answers={[""]}
        onAnswerChange={vi.fn()}
      />
    );

    expect(screen.getByLabelText("Chỗ trống 1")).toBeInTheDocument();
    expect(screen.getByText("world")).toBeInTheDocument();
  });
});
