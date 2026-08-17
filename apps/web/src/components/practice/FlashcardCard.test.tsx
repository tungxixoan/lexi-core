import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { FlashcardCard } from "./FlashcardCard";
import type { VocabRecord } from "@/lib/vocabRecords";

const RECORD: VocabRecord = {
  id: "1",
  headword: "meticulous",
  inputType: "word",
  ipa: "/məˈtɪkjələs/",
  meaning: "tỉ mỉ, cẩn thận",
  examples: ["She is meticulous.", "Second example."],
  personalNotes: "",
  topicIds: [],
  targetLanguage: "english",
  cefrLevel: "c1",
  activeContext: "general",
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 0,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

describe("FlashcardCard", () => {
  it("shows the headword and IPA on the front, and the meaning + only the first example on the back", () => {
    render(<FlashcardCard record={RECORD} onGrade={vi.fn()} />);
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.getByText("/məˈtɪkjələs/")).toBeInTheDocument();
    expect(screen.getByText("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(screen.getByText('"She is meticulous."')).toBeInTheDocument();
    expect(screen.queryByText('"Second example."')).not.toBeInTheDocument();
  });

  it("rotates by 180 degrees when the card is clicked", () => {
    render(<FlashcardCard record={RECORD} onGrade={vi.fn()} />);
    const card = screen.getByTestId("flashcard-card");
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,0deg)" });
    fireEvent.click(card);
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,180deg)" });
  });

  it("rotates forward another 180 degrees (never backward) when the back's peek area is clicked, without grading", () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    const card = screen.getByTestId("flashcard-card");
    fireEvent.click(card); // front -> back (180)
    fireEvent.click(screen.getByText("tỉ mỉ, cẩn thận")); // peek back to front
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,360deg)" });
    expect(onGrade).not.toHaveBeenCalled();
  });

  it("calls onGrade(1) for Chưa hiểu and onGrade(5) for Đã hiểu, rotating forward either way", () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    const card = screen.getByTestId("flashcard-card");
    fireEvent.click(card); // -> 180
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));
    expect(onGrade).toHaveBeenCalledWith(5);
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,360deg)" });
  });

  it("calls onGrade(1), not 5, for Chưa hiểu", () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    fireEvent.click(screen.getByTestId("flashcard-card")); // -> 180
    fireEvent.click(screen.getByRole("button", { name: "Chưa hiểu" }));
    expect(onGrade).toHaveBeenCalledWith(1);
  });
});
