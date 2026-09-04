import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { TranslationCard } from "./TranslationCard";
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
  cefrLevel: "c1",
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

const EXERCISE: Extract<PracticeExercise, { type: "translation" }> = {
  type: "translation",
  record: RECORD,
  prompt: "Translate to Vietnamese: 'It was an ephemeral joy.'",
  answer: "Đó là một niềm vui thoáng qua.",
};

describe("TranslationCard", () => {
  it("renders the header and the stripped prompt", () => {
    render(<TranslationCard exercise={EXERCISE} onGrade={vi.fn()} />);
    expect(screen.getByText("Dịch sang tiếng Việt")).toBeInTheDocument();
    expect(screen.getByText("It was an ephemeral joy.")).toBeInTheDocument();
  });

  it("keeps 'Xem đáp án' disabled until the textarea has text", () => {
    render(<TranslationCard exercise={EXERCISE} onGrade={vi.fn()} />);
    const reveal = screen.getByRole("button", { name: "Xem đáp án" });
    expect(reveal).toBeDisabled();
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "  " } });
    expect(reveal).toBeDisabled();
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "niềm vui" } });
    expect(reveal).toBeEnabled();
  });

  it("reveals the answer and both grade buttons after 'Xem đáp án'", () => {
    render(<TranslationCard exercise={EXERCISE} onGrade={vi.fn()} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "niềm vui" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem đáp án" }));
    expect(screen.getByText("Đáp án: Đó là một niềm vui thoáng qua.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sai rồi" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Đúng rồi" })).toBeInTheDocument();
  });

  it("does not call onGrade before a grade button is pressed", () => {
    const onGrade = vi.fn();
    render(<TranslationCard exercise={EXERCISE} onGrade={onGrade} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "niềm vui" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem đáp án" }));
    expect(onGrade).not.toHaveBeenCalled();
  });

  it("'Đúng rồi' grades 5 and 'Sai rồi' grades 1", () => {
    const onGradeYes = vi.fn();
    const { unmount } = render(<TranslationCard exercise={EXERCISE} onGrade={onGradeYes} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "x" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem đáp án" }));
    fireEvent.click(screen.getByRole("button", { name: "Đúng rồi" }));
    expect(onGradeYes).toHaveBeenCalledWith(5);
    unmount();

    const onGradeNo = vi.fn();
    render(<TranslationCard exercise={EXERCISE} onGrade={onGradeNo} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "x" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem đáp án" }));
    fireEvent.click(screen.getByRole("button", { name: "Sai rồi" }));
    expect(onGradeNo).toHaveBeenCalledWith(1);
  });
});
