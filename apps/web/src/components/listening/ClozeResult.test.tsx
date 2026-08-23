import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { ClozeResult } from "./ClozeResult";

describe("ClozeResult", () => {
  it("shows a correct answer styled correct, with no hint", () => {
    render(
      <ClozeResult
        target="Apple is red"
        blanks={[{ startWordIndex: 0, wordCount: 1 }]}
        answers={["apple"]}
      />
    );

    const answer = screen.getByText("apple");
    expect(answer).toHaveClass("cloze-answer-correct");
    expect(screen.queryByText(/đúng:/)).not.toBeInTheDocument();
  });

  it("shows a wrong answer styled wrong, with the correct text as a hint", () => {
    render(
      <ClozeResult
        target="Apple is red"
        blanks={[{ startWordIndex: 0, wordCount: 1 }]}
        answers={["banana"]}
      />
    );

    expect(screen.getByText("banana")).toHaveClass("cloze-answer-wrong");
    expect(screen.getByText(/đúng: apple/)).toBeInTheDocument();
  });

  it("shows a placeholder for an empty answer, treated as wrong", () => {
    render(
      <ClozeResult target="Apple is red" blanks={[{ startWordIndex: 0, wordCount: 1 }]} answers={[""]} />
    );

    expect(screen.getByText("___")).toHaveClass("cloze-answer-wrong");
  });

  it("renders every surrounding word alongside multiple blanks", () => {
    render(
      <ClozeResult
        target="The quick brown fox jumps"
        blanks={[
          { startWordIndex: 1, wordCount: 1 },
          { startWordIndex: 3, wordCount: 1 },
        ]}
        answers={["quick", "wrong"]}
      />
    );

    expect(screen.getByText(/^The/)).toBeInTheDocument();
    expect(screen.getByText("quick")).toHaveClass("cloze-answer-correct");
    expect(screen.getByText(/jumps/)).toBeInTheDocument();
  });
});
