import { beforeEach, describe, expect, it, vi } from "vitest";
import { act, render, screen } from "@testing-library/react";
import { usePaginatedScroll } from "./usePaginatedScroll";

class FakeIntersectionObserver {
  static instances: FakeIntersectionObserver[] = [];
  callback: IntersectionObserverCallback;
  observedTargets: Element[] = [];
  observe = vi.fn((el: Element) => {
    this.observedTargets.push(el);
  });
  disconnect = vi.fn();
  unobserve = vi.fn();
  constructor(callback: IntersectionObserverCallback) {
    this.callback = callback;
    FakeIntersectionObserver.instances.push(this);
  }
  trigger(target: Element, isIntersecting: boolean) {
    act(() => {
      this.callback([{ isIntersecting, target } as IntersectionObserverEntry], this as never);
    });
  }
}

// Returns the most recently created fake observer that is watching `target`
// — the scroll-tracking observer is torn down and recreated every time
// `visibleCount` changes, so an older, already-disconnected instance may
// still technically list the same target in its (never-cleared) history.
function observerFor(target: Element): FakeIntersectionObserver {
  const matches = FakeIntersectionObserver.instances.filter((o) =>
    o.observedTargets.includes(target)
  );
  const found = matches[matches.length - 1];
  if (!found) throw new Error("No fake IntersectionObserver is watching this element");
  return found;
}

beforeEach(() => {
  FakeIntersectionObserver.instances = [];
  vi.stubGlobal("IntersectionObserver", FakeIntersectionObserver as never);
  Element.prototype.scrollIntoView = vi.fn();
});

const ITEMS = Array.from({ length: 25 }, (_, i) => `item-${i}`);

function TestList({ items, resetKey }: { items: string[]; resetKey: string | number }) {
  const { visibleItems, containerRef, sentinelRef, currentPage, totalPages, jumpToPage } =
    usePaginatedScroll(items, resetKey);
  return (
    <div>
      <div ref={containerRef} data-testid="container">
        {visibleItems.map((item) => (
          <div key={item}>{item}</div>
        ))}
        <div ref={sentinelRef} data-testid="sentinel" />
      </div>
      <p data-testid="page-info">
        {currentPage}/{totalPages}
      </p>
      {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => (
        <button key={page} onClick={() => jumpToPage(page)}>
          page-{page}
        </button>
      ))}
    </div>
  );
}

function clickButton(text: string) {
  act(() => {
    screen.getByText(text).click();
  });
}

function revealSentinel() {
  const sentinel = screen.getByTestId("sentinel");
  observerFor(sentinel).trigger(sentinel, true);
}

function viewRow(text: string) {
  const row = screen.getByText(text);
  observerFor(row).trigger(row, true);
}

describe("usePaginatedScroll", () => {
  it("starts with only the first 10 of 25 items visible, on page 1", () => {
    render(<TestList items={ITEMS} resetKey="a" />);
    expect(screen.getByText("item-0")).toBeInTheDocument();
    expect(screen.getByText("item-9")).toBeInTheDocument();
    expect(screen.queryByText("item-10")).not.toBeInTheDocument();
    expect(screen.getByTestId("page-info")).toHaveTextContent("1/3");
  });

  it("reveals the next 10 items when the sentinel intersects", () => {
    render(<TestList items={ITEMS} resetKey="a" />);
    revealSentinel();
    expect(screen.getByText("item-19")).toBeInTheDocument();
    expect(screen.queryByText("item-20")).not.toBeInTheDocument();
  });

  it("caps visible count at the item list length", () => {
    render(<TestList items={ITEMS} resetKey="a" />);
    revealSentinel();
    revealSentinel();
    revealSentinel();
    expect(screen.getByText("item-24")).toBeInTheDocument();
  });

  it("jumpToPage reveals a not-yet-visible page, scrolls to its first row, and updates the page bar immediately", () => {
    render(<TestList items={ITEMS} resetKey="a" />);
    clickButton("page-3");
    expect(screen.getByText("item-24")).toBeInTheDocument();
    expect(Element.prototype.scrollIntoView).toHaveBeenCalled();
    expect(screen.getByTestId("page-info")).toHaveTextContent("3/3");
  });

  it("jumpToPage scrolls immediately when the target page is already revealed", () => {
    render(<TestList items={ITEMS} resetKey="a" />);
    revealSentinel(); // reveal page 2 (20 visible)
    vi.mocked(Element.prototype.scrollIntoView).mockClear();
    clickButton("page-1");
    expect(Element.prototype.scrollIntoView).toHaveBeenCalledTimes(1);
    expect(screen.getByText("item-19")).toBeInTheDocument(); // still 20 visible, no extra reveal
  });

  it("resets to the first page when resetKey changes (a genuine filter change)", () => {
    const { rerender } = render(<TestList items={ITEMS} resetKey="filter-a" />);
    revealSentinel();
    expect(screen.getByTestId("page-info")).toHaveTextContent("2/3");

    const NEW_ITEMS = Array.from({ length: 5 }, (_, i) => `new-${i}`);
    act(() => {
      rerender(<TestList items={NEW_ITEMS} resetKey="filter-b" />);
    });
    expect(screen.getByTestId("page-info")).toHaveTextContent("1/1");
    expect(screen.getByText("new-0")).toBeInTheDocument();
  });

  it("does NOT reset pagination when items changes but resetKey stays the same (e.g. an edit or delete)", () => {
    const { rerender } = render(<TestList items={ITEMS} resetKey="filter-a" />);
    revealSentinel();
    expect(screen.getByTestId("page-info")).toHaveTextContent("2/3");

    // Simulate an edit/delete: a brand-new array reference, one item
    // removed, but the same filter (same resetKey).
    const MUTATED_ITEMS = ITEMS.filter((_, i) => i !== 24);
    act(() => {
      rerender(<TestList items={MUTATED_ITEMS} resetKey="filter-a" />);
    });
    expect(screen.getByText("item-0")).toBeInTheDocument();
    expect(screen.getByText("item-19")).toBeInTheDocument(); // still showing through page 2
  });

  it("tracks the real scroll position — the page bar reflects the row actually in view, not just how much is revealed", () => {
    render(<TestList items={ITEMS} resetKey="a" />);
    revealSentinel(); // reveal 20 items (page 2)
    expect(screen.getByTestId("page-info")).toHaveTextContent("2/3");

    // Simulate scrolling back up: page 1's first row becomes the topmost visible row again.
    viewRow("item-0");
    expect(screen.getByTestId("page-info")).toHaveTextContent("1/3");
  });
});
