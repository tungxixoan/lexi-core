import { afterEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { FillInBlankCard } from "./FillInBlankCard";
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

const EXERCISE: Extract<PracticeExercise, { type: "fill_in_blank" }> = {
  type: "fill_in_blank",
  record: RECORD,
  sentence: "The ___ moment passed quickly.",
  answer: "ephemeral",
};

afterEach(() => {
  vi.useRealTimers();
});

describe("FillInBlankCard", () => {
  it("renders the header and the text around the blank", () => {
    render(<FillInBlankCard exercise={EXERCISE} onGrade={vi.fn()} />);
    expect(screen.getByText("Điền vào chỗ trống")).toBeInTheDocument();
    expect(screen.getByText(/The/)).toBeInTheDocument();
    expect(screen.getByText(/moment passed quickly\./)).toBeInTheDocument();
  });

  it("grades 5 after 1200ms when the answer matches (case-insensitive) via Kiểm tra", () => {
    vi.useFakeTimers();
    const onGrade = vi.fn();
    render(<FillInBlankCard exercise={EXERCISE} onGrade={onGrade} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "  EPHEMERAL " } });
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra" }));
    expect(onGrade).not.toHaveBeenCalled();
    act(() => vi.advanceTimersByTime(1200));
    expect(onGrade).toHaveBeenCalledTimes(1);
    expect(onGrade).toHaveBeenCalledWith(5);
  });

  it("shows the answer and grades 1 on a wrong submission", () => {
    vi.useFakeTimers();
    const onGrade = vi.fn();
    render(<FillInBlankCard exercise={EXERCISE} onGrade={onGrade} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "wrong" } });
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra" }));
    expect(screen.getByText("Đáp án: ephemeral")).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(1200));
    expect(onGrade).toHaveBeenCalledWith(1);
  });

  it("disables the input after submit", () => {
    render(<FillInBlankCard exercise={EXERCISE} onGrade={vi.fn()} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "ephemeral" } });
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra" }));
    expect(screen.getByRole("textbox")).toBeDisabled();
  });

  it("submits on Enter", () => {
    vi.useFakeTimers();
    const onGrade = vi.fn();
    render(<FillInBlankCard exercise={EXERCISE} onGrade={onGrade} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "ephemeral" } });
    fireEvent.keyDown(screen.getByRole("textbox"), { key: "Enter" });
    act(() => vi.advanceTimersByTime(1200));
    expect(onGrade).toHaveBeenCalledWith(5);
  });

  it("ignores a second Kiểm tra click", () => {
    vi.useFakeTimers();
    const onGrade = vi.fn();
    render(<FillInBlankCard exercise={EXERCISE} onGrade={onGrade} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "ephemeral" } });
    const btn = screen.getByRole("button", { name: "Kiểm tra" });
    fireEvent.click(btn);
    fireEvent.click(btn);
    act(() => vi.advanceTimersByTime(1200));
    expect(onGrade).toHaveBeenCalledTimes(1);
  });
});
