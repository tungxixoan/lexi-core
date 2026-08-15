import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { VocabDrawer } from "./VocabDrawer";
import type { VocabRecord } from "@/lib/vocabRecords";
import type { Topic } from "@/lib/topics";

const RECORD: VocabRecord = {
  id: "1",
  headword: "meticulous",
  inputType: "word",
  ipa: "/məˈtɪkjələs/",
  meaning: "tỉ mỉ, cẩn thận",
  examples: ["She reviewed the contract with meticulous attention to detail."],
  personalNotes: "Hay gặp trong đề TOEIC Part 7.",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "c1",
  activeContext: "business",
  createdAt: "2026-08-01T00:00:00.000Z",
  updatedAt: "2026-08-01T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 3,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "Showing great attention to detail.",
  synonyms: ["thorough", "careful"],
};

const TOPICS: Topic[] = [
  { id: "business", name: "Kinh doanh", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
];

describe("VocabDrawer", () => {
  it("renders the headword, IPA, CEFR pill, meaning, examples, synonyms, resolved topic names, and notes", () => {
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={vi.fn()} />);

    expect(screen.getByRole("heading", { name: "meticulous" })).toBeInTheDocument();
    expect(screen.getByText("/məˈtɪkjələs/")).toBeInTheDocument();
    expect(screen.getByText("C1")).toBeInTheDocument();
    expect(screen.getByText("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(
      screen.getByText(/She reviewed the contract with meticulous attention to detail\./)
    ).toBeInTheDocument();
    expect(screen.getByText("thorough")).toBeInTheDocument();
    expect(screen.getByText("Kinh doanh")).toBeInTheDocument();
    expect(screen.getByText("Hay gặp trong đề TOEIC Part 7.")).toBeInTheDocument();
  });

  it("shows the computed mastery percentage", () => {
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={vi.fn()} />);
    // sm2Repetitions=3, sm2EaseFactor=2.5 -> 50% (see vocabDisplay.test.ts)
    expect(screen.getByText("50%")).toBeInTheDocument();
  });

  it("calls onClose when the close button is clicked", () => {
    const onClose = vi.fn();
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={onClose} onDelete={vi.fn()} />);
    fireEvent.click(screen.getByLabelText("Đóng"));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it("calls onDelete when Xoá is clicked", () => {
    const onDelete = vi.fn();
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={onDelete} />);
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));
    expect(onDelete).toHaveBeenCalledOnce();
  });

  it("renders Sửa as disabled (deferred — no edit-flow mockup exists yet)", () => {
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByRole("button", { name: "Sửa" })).toBeDisabled();
  });
});
