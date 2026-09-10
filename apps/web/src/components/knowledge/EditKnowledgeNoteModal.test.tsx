import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { EditKnowledgeNoteModal } from "./EditKnowledgeNoteModal";
import type { KnowledgeNoteDraft } from "@/lib/knowledgeNoteSource";
import type { KnowledgeNote } from "@/lib/knowledgeNotes";

const draft: KnowledgeNoteDraft = {
  title: "Câu điều kiện loại 2",
  summary: "S",
  explanation: "E",
  patterns: [],
  examples: [],
  pitfalls: [],
  suggestedGroupId: "en_conditionals",
  suggestedCefr: "b1",
  suggestedTags: [],
  relatedNoteId: null,
};

describe("EditKnowledgeNoteModal", () => {
  it("review-draft: prefills and saves an ai note with the suggested group + sourcePrompt", async () => {
    const onSave = vi.fn().mockResolvedValue(undefined);
    render(
      <EditKnowledgeNoteModal
        draft={draft}
        sourcePrompt="loại 2"
        targetLanguage="english"
        existingNotes={[]}
        onClose={() => {}}
        onSave={onSave}
      />,
    );
    expect(screen.getByDisplayValue("Câu điều kiện loại 2")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(onSave).toHaveBeenCalled());
    const saved = onSave.mock.calls[0][0] as KnowledgeNote;
    expect(saved.source).toBe("ai");
    expect(saved.groupId).toBe("en_conditionals");
    expect(saved.sourcePrompt).toBe("loại 2");
  });

  it("blank-new: empty title blocks the save and shows the error", () => {
    const onSave = vi.fn();
    render(
      <EditKnowledgeNoteModal
        targetLanguage="english"
        existingNotes={[]}
        onClose={() => {}}
        onSave={onSave}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    expect(onSave).not.toHaveBeenCalled();
    expect(screen.getByText(/Nhập tiêu đề/)).toBeInTheDocument();
  });

  it("AI overwrite of a manual note keeps origin manual", async () => {
    const onSave = vi.fn().mockResolvedValue(undefined);
    const existing: KnowledgeNote = {
      id: "m1",
      title: "Câu điều kiện loại 2 (cũ)",
      summary: "S cũ",
      explanation: "E cũ",
      patterns: [],
      examples: [],
      pitfalls: [],
      groupId: "en_conditionals",
      tags: [],
      cefrLevel: "b1",
      targetLanguage: "english",
      source: "manual",
      sourcePrompt: null,
      createdAt: "2020-01-01T00:00:00.000Z",
      updatedAt: "2020-01-01T00:00:00.000Z",
    };
    render(
      <EditKnowledgeNoteModal
        draft={draft}
        overwriteNoteId="m1"
        targetLanguage="english"
        existingNotes={[existing]}
        onClose={() => {}}
        onSave={onSave}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(onSave).toHaveBeenCalled());
    const saved = onSave.mock.calls[0][0] as KnowledgeNote;
    expect(saved.source).toBe("manual");
    expect(saved.createdAt).toBe("2020-01-01T00:00:00.000Z");
  });
});
