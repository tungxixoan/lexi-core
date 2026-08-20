import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { TypingSentence } from "./TypingSentence";
import type { BilingualSentence } from "@/lib/readingPassage";

const CURRENT: BilingualSentence = {
  target: "The meeting was rescheduled.",
  vietnamese: "Cuộc họp đã được dời lại.",
  vocabWords: ["rescheduled"],
};

describe("TypingSentence", () => {
  it("shows the Vietnamese translation of the current sentence", () => {
    render(
      <TypingSentence
        completedSentences={[]}
        currentSentence={CURRENT}
        typed=""
        onTypedChange={vi.fn()}
      />
    );
    expect(screen.getByText("Cuộc họp đã được dời lại.")).toBeInTheDocument();
  });

  it("shows previously completed sentences alongside the current one", () => {
    render(
      <TypingSentence
        completedSentences={["She works at a bank."]}
        currentSentence={CURRENT}
        typed=""
        onTypedChange={vi.fn()}
      />
    );
    expect(screen.getByText(/She works at a bank\./)).toBeInTheDocument();
  });

  it("colors correctly-typed characters differently from incorrectly-typed ones", () => {
    render(
      <TypingSentence
        completedSentences={[]}
        currentSentence={CURRENT}
        typed="Thx"
        onTypedChange={vi.fn()}
      />
    );
    const input = screen.getByTestId("reading-type-input");
    const passage = input.parentElement!;
    const okChars = passage.querySelectorAll(".reading-char-ok");
    const badChars = passage.querySelectorAll(".reading-char-bad");
    expect(okChars).toHaveLength(2); // "T", "h" match
    expect(badChars).toHaveLength(1); // "x" doesn't match "e"
  });

  it("calls onTypedChange with the new input value on every keystroke", () => {
    const onTypedChange = vi.fn();
    render(
      <TypingSentence
        completedSentences={[]}
        currentSentence={CURRENT}
        typed="The"
        onTypedChange={onTypedChange}
      />
    );
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "The " } });
    expect(onTypedChange).toHaveBeenCalledWith("The ");
  });

  it("does not reveal any sentence after the current one", () => {
    render(
      <TypingSentence
        completedSentences={[]}
        currentSentence={CURRENT}
        typed=""
        onTypedChange={vi.fn()}
      />
    );
    expect(screen.queryByText(/next sentence/i)).not.toBeInTheDocument();
  });
});
