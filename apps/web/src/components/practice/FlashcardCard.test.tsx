import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { FlashcardCard } from "./FlashcardCard";
import type { VocabRecord } from "@/lib/vocabRecords";

vi.mock("@/lib/pronunciation", async () => {
  const actual = await vi.importActual<typeof import("@/lib/pronunciation")>("@/lib/pronunciation");
  return { ...actual, getPronunciationUrl: vi.fn() };
});

beforeEach(() => {
  vi.clearAllMocks();
  window.HTMLMediaElement.prototype.play = vi.fn().mockResolvedValue(undefined);
});

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

  it("shows a pronunciation button for the headword on the front", () => {
    render(<FlashcardCard record={RECORD} onGrade={vi.fn()} />);
    expect(
      screen.getByRole("button", { name: "Nghe phát âm: meticulous" })
    ).toBeInTheDocument();
  });

  it("tapping the pronunciation button plays audio without flipping the card", () => {
    render(<FlashcardCard record={RECORD} onGrade={vi.fn()} />);
    const card = screen.getByTestId("flashcard-card");
    fireEvent.click(screen.getByRole("button", { name: "Nghe phát âm: meticulous" }));
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,0deg)" });
  });

  it("hides the pronunciation button when the target language has no TTS voice", () => {
    render(
      <FlashcardCard
        record={{ ...RECORD, targetLanguage: "japanese" }}
        onGrade={vi.fn()}
      />
    );
    expect(screen.queryByRole("button", { name: /Nghe phát âm/ })).not.toBeInTheDocument();
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

  it("on grade: the card turns over blank (is-grading) and reports the grade once the flip settles", async () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    const card = screen.getByTestId("flashcard-card");
    fireEvent.click(card); // front -> back (180)
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));

    // Immediately: one more half-turn (360), every face hidden via .is-grading,
    // and the grade is not reported until that flip finishes.
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,360deg)" });
    expect(card).toHaveClass("is-grading");
    expect(onGrade).not.toHaveBeenCalled();

    await waitFor(() => expect(onGrade).toHaveBeenCalledWith(5));
  });

  it("reports quality 1 for Chưa hiểu once the flip settles", async () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    fireEvent.click(screen.getByTestId("flashcard-card")); // -> 180
    fireEvent.click(screen.getByRole("button", { name: "Chưa hiểu" }));
    await waitFor(() => expect(onGrade).toHaveBeenCalledWith(1));
  });

  it("ignores a second grade tap while the first flip-out is still running", async () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    fireEvent.click(screen.getByTestId("flashcard-card")); // -> 180
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));
    fireEvent.click(screen.getByRole("button", { name: "Chưa hiểu" }));
    await waitFor(() => expect(onGrade).toHaveBeenCalledTimes(1));
    expect(onGrade).toHaveBeenCalledWith(5);
  });

  it("renders a semicolon-separated multi-sense meaning as separate lines", () => {
    render(
      <FlashcardCard
        record={{ ...RECORD, meaning: "đề xuất; khuyên" }}
        onGrade={vi.fn()}
      />
    );
    expect(screen.getByText("đề xuất")).toBeInTheDocument();
    expect(screen.getByText("khuyên")).toBeInTheDocument();
    expect(screen.queryByText("đề xuất; khuyên")).not.toBeInTheDocument();
  });
});
