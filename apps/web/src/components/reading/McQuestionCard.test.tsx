import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { McQuestionCard } from "./McQuestionCard";

describe("McQuestionCard (session mode)", () => {
  it("renders the label and every option, calling onSelect with the clicked option's index", () => {
    const onSelect = vi.fn();
    render(
      <McQuestionCard label="1. She ___ to work." options={["go", "goes", "going", "gone"]} selected={null} onSelect={onSelect} />
    );

    expect(screen.getByText("1. She ___ to work.")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "goes" }));

    expect(onSelect).toHaveBeenCalledWith(1);
  });

  it("marks the selected option without disabling any option", () => {
    render(<McQuestionCard label="Q" options={["a", "b"]} selected={1} onSelect={vi.fn()} />);

    expect(screen.getByRole("button", { name: "a" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: "b" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: "a" })).toHaveAttribute("aria-pressed", "false");
  });
});

describe("McQuestionCard (result mode)", () => {
  it("disables every option and highlights the correct one when the user answered correctly", () => {
    render(<McQuestionCard label="Q" options={["a", "b", "c"]} selected={1} correctIndex={1} explanation="Vì lý do X." />);

    expect(screen.getByRole("button", { name: "a" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "b" })).toHaveClass("mc-option-correct");
    expect(screen.getByRole("button", { name: "c" })).not.toHaveClass("mc-option-correct");
    expect(screen.getByRole("button", { name: "c" })).not.toHaveClass("mc-option-wrong");
    expect(screen.getByText("Giải thích: Vì lý do X.")).toBeInTheDocument();
  });

  it("highlights the correct option green and the user's wrong pick red when the user answered incorrectly", () => {
    render(<McQuestionCard label="Q" options={["a", "b", "c"]} selected={2} correctIndex={0} explanation="Vì lý do X." />);

    expect(screen.getByRole("button", { name: "a" })).toHaveClass("mc-option-correct");
    expect(screen.getByRole("button", { name: "c" })).toHaveClass("mc-option-wrong");
    expect(screen.getByRole("button", { name: "b" })).not.toHaveClass("mc-option-correct");
    expect(screen.getByRole("button", { name: "b" })).not.toHaveClass("mc-option-wrong");
  });

  it("does not call onSelect when an option is clicked in result mode (options are disabled)", () => {
    const onSelect = vi.fn();
    render(<McQuestionCard label="Q" options={["a", "b"]} selected={0} onSelect={onSelect} correctIndex={0} />);

    fireEvent.click(screen.getByRole("button", { name: "b" }));

    expect(onSelect).not.toHaveBeenCalled();
  });

  it("renders no explanation paragraph when none is given", () => {
    render(<McQuestionCard label="Q" options={["a", "b"]} selected={0} correctIndex={0} />);
    expect(screen.queryByText(/Giải thích:/)).not.toBeInTheDocument();
  });
});
