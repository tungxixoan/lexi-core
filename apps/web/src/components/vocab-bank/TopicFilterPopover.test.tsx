import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { TopicFilterPopover } from "./TopicFilterPopover";
import type { Topic } from "@/lib/topics";

const TOPICS: Topic[] = [
  { id: "business", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
  { id: "travel", name: "Travel", emoji: "✈️", isPredefined: true, createdAt: "2026-01-01" },
  { id: "academic", name: "Academic", emoji: "🎓", isPredefined: true, createdAt: "2026-01-01" },
];

describe("TopicFilterPopover", () => {
  it("shows the trigger closed by default, with no count when nothing is selected", () => {
    render(<TopicFilterPopover topics={TOPICS} selectedTopicIds={new Set()} onApply={vi.fn()} />);
    expect(screen.getByRole("button", { name: "Chủ đề ▾" })).toBeInTheDocument();
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("shows the selected count on the trigger", () => {
    render(
      <TopicFilterPopover
        topics={TOPICS}
        selectedTopicIds={new Set(["business", "travel"])}
        onApply={vi.fn()}
      />
    );
    expect(screen.getByRole("button", { name: "Chủ đề ▾ (2)" })).toBeInTheDocument();
  });

  it("opens the popover listing every topic, not just ones with saved words", () => {
    render(<TopicFilterPopover topics={TOPICS} selectedTopicIds={new Set()} onApply={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", { name: "Chủ đề ▾" }));
    expect(screen.getByRole("dialog")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "💼 Business" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "✈️ Travel" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "🎓 Academic" })).toBeInTheDocument();
  });

  it("toggling a topic inside the popover does not call onApply until Áp dụng is clicked", () => {
    const onApply = vi.fn();
    render(<TopicFilterPopover topics={TOPICS} selectedTopicIds={new Set()} onApply={onApply} />);
    fireEvent.click(screen.getByRole("button", { name: "Chủ đề ▾" }));
    fireEvent.click(screen.getByRole("button", { name: "💼 Business" }));
    expect(onApply).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(onApply).toHaveBeenCalledWith(new Set(["business"]));
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("reopening the popover starts the draft from the current committed selection, discarding any earlier uncommitted toggle", () => {
    const onApply = vi.fn();
    const { rerender } = render(
      <TopicFilterPopover topics={TOPICS} selectedTopicIds={new Set(["business"])} onApply={onApply} />
    );
    fireEvent.click(screen.getByRole("button", { name: "Chủ đề ▾ (1)" }));
    fireEvent.click(screen.getByRole("button", { name: "✈️ Travel" })); // draft now business+travel, uncommitted
    fireEvent.click(screen.getByRole("button", { name: "Chủ đề ▾ (1)" })); // close without applying

    rerender(
      <TopicFilterPopover topics={TOPICS} selectedTopicIds={new Set(["business"])} onApply={onApply} />
    );
    fireEvent.click(screen.getByRole("button", { name: "Chủ đề ▾ (1)" })); // reopen
    expect(screen.getByRole("button", { name: "✈️ Travel" })).not.toHaveClass("active");
    expect(screen.getByRole("button", { name: "💼 Business" })).toHaveClass("active");
  });
});
