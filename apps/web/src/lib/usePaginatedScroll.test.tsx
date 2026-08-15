import { beforeEach, describe, expect, it, vi } from "vitest";
import { act, render, screen } from "@testing-library/react";
import { usePaginatedScroll } from "./usePaginatedScroll";

class FakeIntersectionObserver {
  static instances: FakeIntersectionObserver[] = [];
  callback: IntersectionObserverCallback;
  observe = vi.fn();
  disconnect = vi.fn();
  unobserve = vi.fn();
  constructor(callback: IntersectionObserverCallback) {
    this.callback = callback;
    FakeIntersectionObserver.instances.push(this);
  }
  trigger(isIntersecting: boolean) {
    act(() => {
      this.callback([{ isIntersecting } as IntersectionObserverEntry], this as never);
    });
  }
}

beforeEach(() => {
  FakeIntersectionObserver.instances = [];
  vi.stubGlobal("IntersectionObserver", FakeIntersectionObserver as never);
  Element.prototype.scrollIntoView = vi.fn();
});

const ITEMS = Array.from({ length: 25 }, (_, i) => `item-${i}`);

function TestList({ items }: { items: string[] }) {
  const { visibleItems, containerRef, sentinelRef, currentPage, totalPages, jumpToPage } =
    usePaginatedScroll(items);
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

describe("usePaginatedScroll", () => {
  it("starts with only the first 10 of 25 items visible", () => {
    render(<TestList items={ITEMS} />);
    expect(screen.getByText("item-0")).toBeInTheDocument();
    expect(screen.getByText("item-9")).toBeInTheDocument();
    expect(screen.queryByText("item-10")).not.toBeInTheDocument();
    expect(screen.getByTestId("page-info")).toHaveTextContent("1/3");
  });

  it("reveals the next 10 items when the sentinel intersects", () => {
    render(<TestList items={ITEMS} />);
    FakeIntersectionObserver.instances[0]?.trigger(true);
    expect(screen.getByText("item-19")).toBeInTheDocument();
    expect(screen.queryByText("item-20")).not.toBeInTheDocument();
    expect(screen.getByTestId("page-info")).toHaveTextContent("2/3");
  });

  it("caps visible count at the item list length", () => {
    render(<TestList items={ITEMS} />);
    FakeIntersectionObserver.instances[0]?.trigger(true);
    FakeIntersectionObserver.instances[0]?.trigger(true);
    FakeIntersectionObserver.instances[0]?.trigger(true);
    expect(screen.getByText("item-24")).toBeInTheDocument();
    expect(screen.getByTestId("page-info")).toHaveTextContent("3/3");
  });

  it("jumpToPage reveals a not-yet-visible page and scrolls to its first row", () => {
    render(<TestList items={ITEMS} />);
    clickButton("page-3");
    expect(screen.getByText("item-24")).toBeInTheDocument();
    expect(Element.prototype.scrollIntoView).toHaveBeenCalled();
  });

  it("jumpToPage scrolls immediately when the target page is already revealed", () => {
    render(<TestList items={ITEMS} />);
    FakeIntersectionObserver.instances[0]?.trigger(true); // reveal page 2 (20 visible)
    vi.mocked(Element.prototype.scrollIntoView).mockClear();
    clickButton("page-1");
    expect(Element.prototype.scrollIntoView).toHaveBeenCalledTimes(1);
    // still 20 visible, no extra reveal happened
    expect(screen.getByText("item-19")).toBeInTheDocument();
  });

  it("resets to the first page when the item list changes", () => {
    const { rerender } = render(<TestList items={ITEMS} />);
    FakeIntersectionObserver.instances[0]?.trigger(true);
    expect(screen.getByTestId("page-info")).toHaveTextContent("2/3");

    const NEW_ITEMS = Array.from({ length: 5 }, (_, i) => `new-${i}`);
    act(() => {
      rerender(<TestList items={NEW_ITEMS} />);
    });
    expect(screen.getByTestId("page-info")).toHaveTextContent("1/1");
    expect(screen.getByText("new-0")).toBeInTheDocument();
    expect(screen.getByText("new-4")).toBeInTheDocument();
  });
});
