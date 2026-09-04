import { afterEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { MultipleChoiceCard } from "./MultipleChoiceCard";
import type { PracticeExercise } from "@/lib/practiceExercise";
import type { VocabRecord } from "@/lib/vocabRecords";

const RECORD: VocabRecord = {
  id: "1",
  headword: "ephemeral",
  inputType: "word",
  ipa: "",
  meaning: "chỉ tồn tại trong thời gian rất ngắn",
  examples: ["An ephemeral trend."],
  personalNotes: "",
  topicIds: [],
  targetLanguage: "english",
  cefrLevel: "b2",
  activeContext: "general",
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 3,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

const EXERCISE: Extract<PracticeExercise, { type: "multiple_choice" }> = {
  type: "multiple_choice",
  record: RECORD,
  question: "What does 'ephemeral' mean?",
  options: ["short-lived", "eternal", "loud", "green"],
  correctIndex: 0,
};

afterEach(() => {
  vi.useRealTimers();
});

describe("MultipleChoiceCard", () => {
  it("renders the question and all four options", () => {
    render(<MultipleChoiceCard exercise={EXERCISE} onGrade={vi.fn()} />);
    expect(screen.getByText("What does 'ephemeral' mean?")).toBeInTheDocument();
    for (const opt of EXERCISE.options) {
      expect(screen.getByRole("button", { name: opt })).toBeInTheDocument();
    }
  });

  it("grades 5 after 800ms when the correct option is picked", () => {
    vi.useFakeTimers();
    const onGrade = vi.fn();
    render(<MultipleChoiceCard exercise={EXERCISE} onGrade={onGrade} />);
    fireEvent.click(screen.getByRole("button", { name: "short-lived" }));
    expect(onGrade).not.toHaveBeenCalled();
    act(() => vi.advanceTimersByTime(800));
    expect(onGrade).toHaveBeenCalledTimes(1);
    expect(onGrade).toHaveBeenCalledWith(5);
  });

  it("grades 1 after 800ms when a wrong option is picked", () => {
    vi.useFakeTimers();
    const onGrade = vi.fn();
    render(<MultipleChoiceCard exercise={EXERCISE} onGrade={onGrade} />);
    fireEvent.click(screen.getByRole("button", { name: "eternal" }));
    act(() => vi.advanceTimersByTime(800));
    expect(onGrade).toHaveBeenCalledWith(1);
  });

  it("marks the correct option and the wrong picked option after a pick", () => {
    render(<MultipleChoiceCard exercise={EXERCISE} onGrade={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", { name: "eternal" }));
    expect(screen.getByRole("button", { name: "short-lived" })).toHaveClass("pe-mc-correct");
    expect(screen.getByRole("button", { name: "eternal" })).toHaveClass("pe-mc-wrong");
  });

  it("ignores a second click after the first pick", () => {
    vi.useFakeTimers();
    const onGrade = vi.fn();
    render(<MultipleChoiceCard exercise={EXERCISE} onGrade={onGrade} />);
    fireEvent.click(screen.getByRole("button", { name: "short-lived" }));
    fireEvent.click(screen.getByRole("button", { name: "eternal" }));
    act(() => vi.advanceTimersByTime(800));
    expect(onGrade).toHaveBeenCalledTimes(1);
    expect(onGrade).toHaveBeenCalledWith(5);
  });
});
