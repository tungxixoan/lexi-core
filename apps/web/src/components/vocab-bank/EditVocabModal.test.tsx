import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { EditVocabModal } from "./EditVocabModal";
import type { VocabRecord } from "@/lib/vocabRecords";
import type { Topic } from "@/lib/topics";

const RECORD: VocabRecord = {
  id: "1",
  headword: "meticulous",
  inputType: "word",
  ipa: "/məˈtɪkjələs/",
  meaning: "tỉ mỉ, cẩn thận",
  examples: ["Câu ví dụ 1"],
  personalNotes: "ghi chú cũ",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "c1",
  activeContext: "business",
  createdAt: "2026-08-01T00:00:00.000Z",
  updatedAt: "2026-08-01T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 0,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "some definition",
  synonyms: ["thorough"],
};

const TOPICS: Topic[] = [
  { id: "business", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
  { id: "travel", name: "Travel", emoji: "✈️", isPredefined: true, createdAt: "2026-01-01" },
  { id: "academic", name: "Academic", emoji: "🎓", isPredefined: true, createdAt: "2026-01-01" },
];

describe("EditVocabModal", () => {
  it("prefills the editable fields with the record's current values", () => {
    render(<EditVocabModal record={RECORD} topics={TOPICS} onClose={vi.fn()} onSave={vi.fn()} />);
    expect(screen.getByDisplayValue("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Câu ví dụ 1")).toBeInTheDocument();
    expect(screen.getByDisplayValue("ghi chú cũ")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Business" })).toHaveClass("active");
  });

  it("adds and removes example rows", () => {
    render(<EditVocabModal record={RECORD} topics={TOPICS} onClose={vi.fn()} onSave={vi.fn()} />);
    fireEvent.click(screen.getByText("+ Thêm ví dụ"));
    expect(screen.getAllByRole("textbox").length).toBeGreaterThan(3); // meaning + 2 examples + notes

    fireEvent.click(screen.getAllByLabelText("Xoá ví dụ")[0]);
    expect(screen.queryByDisplayValue("Câu ví dụ 1")).not.toBeInTheDocument();
  });

  it("caps topic selection at 2, but always allows deselecting an already-selected one", () => {
    render(<EditVocabModal record={RECORD} topics={TOPICS} onClose={vi.fn()} onSave={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", { name: "Travel" }));
    expect(screen.getByRole("button", { name: "Travel" })).toHaveClass("active");

    // both business + travel selected now (2/2) -> academic should be disabled
    expect(screen.getByRole("button", { name: "Academic" })).toBeDisabled();

    // deselecting an already-picked one must still work even at the cap
    fireEvent.click(screen.getByRole("button", { name: "Business" }));
    expect(screen.getByRole("button", { name: "Business" })).not.toHaveClass("active");
    expect(screen.getByRole("button", { name: "Academic" })).not.toBeDisabled();
  });

  it("calls onClose (not onSave) when Huỷ is clicked", () => {
    const onClose = vi.fn();
    const onSave = vi.fn();
    render(<EditVocabModal record={RECORD} topics={TOPICS} onClose={onClose} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "Huỷ" }));
    expect(onClose).toHaveBeenCalledOnce();
    expect(onSave).not.toHaveBeenCalled();
  });

  it("calls onSave with the trimmed, filtered payload when Lưu is clicked", async () => {
    const onSave = vi.fn().mockResolvedValue(undefined);
    render(<EditVocabModal record={RECORD} topics={TOPICS} onClose={vi.fn()} onSave={onSave} />);

    fireEvent.change(screen.getByDisplayValue("tỉ mỉ, cẩn thận"), {
      target: { value: "  nghĩa mới  " },
    });

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(onSave).toHaveBeenCalledWith({
        meaning: "nghĩa mới",
        examples: ["Câu ví dụ 1"],
        topicIds: ["business"],
        personalNotes: "ghi chú cũ",
      })
    );
  });

  it("shows an alert and re-enables Lưu when onSave rejects", async () => {
    const onSave = vi.fn().mockRejectedValue(new Error("permission-denied"));
    render(<EditVocabModal record={RECORD} topics={TOPICS} onClose={vi.fn()} onSave={onSave} />);

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent("permission-denied")
    );
    expect(screen.getByRole("button", { name: "Lưu" })).not.toBeDisabled();
  });

  it("closes when the backdrop is clicked but not when the modal content is clicked", () => {
    const onClose = vi.fn();
    render(<EditVocabModal record={RECORD} topics={TOPICS} onClose={onClose} onSave={vi.fn()} />);

    fireEvent.click(screen.getByRole("dialog"));
    expect(onClose).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("presentation"));
    expect(onClose).toHaveBeenCalledOnce();
  });
});
