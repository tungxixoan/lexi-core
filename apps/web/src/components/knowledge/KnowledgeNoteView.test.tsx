import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { KnowledgeNoteView } from "./KnowledgeNoteView";
import { noteFixture } from "./testUtils";

describe("KnowledgeNoteView", () => {
  it("renders present sections, hides empty ones", () => {
    render(
      <KnowledgeNoteView
        note={noteFixture({ explanation: "a **b**", patterns: ["If ..."], examples: [], pitfalls: [] })}
        knownHeadwords={[]}
        onDelete={() => {}}
      />,
    );
    expect(screen.getByText("Mẫu câu")).toBeInTheDocument();
    expect(screen.queryByText("Lỗi thường gặp")).toBeNull();
    expect(screen.queryByText("Ví dụ")).toBeNull();
  });

  it("shows a Mẫu pill for a starter note", () => {
    render(
      <KnowledgeNoteView note={noteFixture({ source: "starter" })} knownHeadwords={[]} onDelete={() => {}} />,
    );
    expect(screen.getByText("Mẫu")).toBeInTheDocument();
  });

  it("renders examples with known-word highlighting over the translation", () => {
    render(
      <KnowledgeNoteView
        note={noteFixture({
          examples: [{ text: "I like apples.", translation: "Tôi thích táo." }],
        })}
        knownHeadwords={["apples"]}
        onDelete={() => {}}
      />,
    );
    expect(screen.getByText("Ví dụ")).toBeInTheDocument();
    expect(screen.getByText("apples")).toHaveClass("known-highlight-static");
    expect(screen.getByText("Tôi thích táo.")).toBeInTheDocument();
  });

  it("asks for confirmation before calling onDelete", () => {
    const onDelete = vi.fn();
    render(<KnowledgeNoteView note={noteFixture()} knownHeadwords={[]} onDelete={onDelete} />);
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));
    expect(onDelete).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận xoá?" }));
    expect(onDelete).toHaveBeenCalled();
  });

  it("links Sửa to the edit route", () => {
    render(<KnowledgeNoteView note={noteFixture({ id: "n1" })} knownHeadwords={[]} onDelete={() => {}} />);
    expect(screen.getByRole("link", { name: "Sửa" })).toHaveAttribute("href", "/knowledge/note/n1/edit");
  });
});
