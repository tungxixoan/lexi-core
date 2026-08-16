# Vocab Bank Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three follow-up enhancements to the already-shipped Vocab Bank screen: the app shell fills the full viewport width, filter chips become multi-select with a client-side cached/paginated scroll list, and vocab records become editable (meaning, examples, topics, notes) via a modal.

**Architecture:** All three pieces build directly on React Web Plan 3 Phase A's existing files (`apps/web/src/app/(app)/vocab-bank/page.tsx`, `apps/web/src/components/vocab-bank/VocabDrawer.tsx`, `apps/web/src/lib/vocabRecords.ts`, `apps/web/src/styles/bloom.css`) — no new routes, no new Cloud Functions. Filtering and pagination both operate entirely on the already-fully-loaded in-memory `records` array (no new Firestore queries); only the new edit flow adds one new Firestore write (`updateVocabRecord`).

**Tech Stack:** Same as React Web Plan 3 Phase A — Next.js 16 App Router, React 19, Firebase JS SDK v12 (`firebase/firestore`), Vitest + React Testing Library + jsdom.

## Global Constraints

- All user-facing text is Vietnamese, matching the existing screen's copy style exactly.
- Import alias `@/` maps to `apps/web/src/`.
- Every new/changed file gets a colocated Vitest test.
- No new Cloud Functions / backend calls — the only new Firestore operation is a client-side `updateDoc` write (`updateVocabRecord`), following the exact same pattern as the existing `deleteVocabRecord`.
- Filter semantics: **OR** between multiple selections within one facet (topics, or CEFR levels), **AND** across facets (topic ∩ CEFR ∩ due-only). "Tất cả" and "Xoá lọc" both reset all three facets to empty.
- Pagination/"lazy load" is entirely client-side over the already-loaded `records` array — no new Firestore queries, no cursors, no composite indexes. `PAGE_SIZE = 10`.
- Edit modal editable fields: `meaning`, `examples`, `topicIds` (max 2), `personalNotes` only — matches the existing Flutter `SaveVocabSheet` field set and the max-2-topics constraint exactly. `headword`, `ipa`, `definition`, `synonyms`, `cefrLevel`, `targetLanguage` stay read-only.
- Verify each task with `npm --prefix apps/web test` (full suite). Finish the plan with `npm --prefix apps/web run typecheck` and `npm --prefix apps/web run build`.

---

## Task 1: Full-width app shell

**Files:**
- Modify: `apps/web/src/styles/bloom.css`
- Test: `apps/web/src/styles/bloom.test.ts`

**Interfaces:**
- Produces: `.app-frame` with no `max-width` cap (still keeps `border-radius`, `border`, `box-shadow`, the `::before` gradient blob).

- [ ] **Step 1: Write the failing test**

Add to `apps/web/src/styles/bloom.test.ts`, inside the existing `describe("bloom.css design tokens", ...)` block:

```ts
  it("app-frame has no max-width cap but keeps the floating-card look", () => {
    const frameBlock = css.match(/\.app-frame \{[^}]*\}/)?.[0] ?? "";
    expect(frameBlock).not.toContain("max-width");
    expect(frameBlock).toContain("border-radius: 26px;");
    expect(frameBlock).toContain("box-shadow");
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `frameBlock` still contains `max-width: 1440px;`.

- [ ] **Step 3: Remove the cap**

Modify `apps/web/src/styles/bloom.css` — in the `.app-frame` rule, delete the `max-width: 1440px;` line so it reads:

```css
.app-frame {
  margin: 0 auto;
  min-height: calc(100vh - 48px);
  background: var(--surface);
  border-radius: 26px;
  border: 1px solid var(--border);
  box-shadow: 0 32px 76px -36px rgba(120, 70, 90, 0.38);
  overflow: hidden;
  display: flex;
  position: relative;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/styles/bloom.css apps/web/src/styles/bloom.test.ts
git commit -m "feat(web): remove app-frame max-width cap for wide screens"
```

---

## Task 2: Multi-select filters (topics/CEFR OR-within, AND-across, due toggle, clear)

**Files:**
- Create: `apps/web/src/lib/vocabFilters.ts`
- Create: `apps/web/src/lib/vocabFilters.test.ts`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `VocabRecord` (`@/lib/vocabRecords`).
- Produces: `VocabFilterState` type, `matchesFilters(record, filters, isDue): boolean`, `isFilterActive(filters): boolean` — from `@/lib/vocabFilters`, used by Task 4 too (no change needed there, `filtered` stays a `VocabRecord[]`).

- [ ] **Step 1: Write the failing tests for the pure filter logic**

Create `apps/web/src/lib/vocabFilters.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { isFilterActive, matchesFilters, type VocabFilterState } from "./vocabFilters";
import type { VocabRecord } from "./vocabRecords";

const BASE: VocabRecord = {
  id: "1",
  headword: "test",
  inputType: "word",
  ipa: "",
  meaning: "",
  examples: [],
  personalNotes: "",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "b2",
  activeContext: "business",
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 0,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

const EMPTY: VocabFilterState = { dueOnly: false, topicIds: new Set(), cefrLevels: new Set() };
const isDueTrue = () => true;
const isDueFalse = () => false;

describe("matchesFilters", () => {
  it("matches everything when no filter is active", () => {
    expect(matchesFilters(BASE, EMPTY, isDueFalse)).toBe(true);
  });

  it("dueOnly filters out non-due records", () => {
    expect(matchesFilters(BASE, { ...EMPTY, dueOnly: true }, isDueTrue)).toBe(true);
    expect(matchesFilters(BASE, { ...EMPTY, dueOnly: true }, isDueFalse)).toBe(false);
  });

  it("topicIds is OR within the facet", () => {
    const filters = { ...EMPTY, topicIds: new Set(["business", "travel"]) };
    expect(matchesFilters(BASE, filters, isDueFalse)).toBe(true); // BASE has "business"
    const filtersNoMatch = { ...EMPTY, topicIds: new Set(["travel", "academic"]) };
    expect(matchesFilters(BASE, filtersNoMatch, isDueFalse)).toBe(false);
  });

  it("cefrLevels is OR within the facet", () => {
    const filters = { ...EMPTY, cefrLevels: new Set(["b2", "c1"]) };
    expect(matchesFilters(BASE, filters, isDueFalse)).toBe(true); // BASE is "b2"
    const filtersNoMatch = { ...EMPTY, cefrLevels: new Set(["a1", "c2"]) };
    expect(matchesFilters(BASE, filtersNoMatch, isDueFalse)).toBe(false);
  });

  it("combines facets with AND", () => {
    // BASE is topic "business", level "b2"
    const matchesBoth = { ...EMPTY, topicIds: new Set(["business"]), cefrLevels: new Set(["b2"]) };
    expect(matchesFilters(BASE, matchesBoth, isDueFalse)).toBe(true);

    const topicOnlyMatches = {
      ...EMPTY,
      topicIds: new Set(["business"]),
      cefrLevels: new Set(["c1"]), // BASE is b2, not c1 -> AND fails
    };
    expect(matchesFilters(BASE, topicOnlyMatches, isDueFalse)).toBe(false);
  });
});

describe("isFilterActive", () => {
  it("is false when every facet is empty", () => {
    expect(isFilterActive(EMPTY)).toBe(false);
  });

  it("is true when any facet is non-empty", () => {
    expect(isFilterActive({ ...EMPTY, dueOnly: true })).toBe(true);
    expect(isFilterActive({ ...EMPTY, topicIds: new Set(["business"]) })).toBe(true);
    expect(isFilterActive({ ...EMPTY, cefrLevels: new Set(["b2"]) })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./vocabFilters` does not exist.

- [ ] **Step 3: Implement the pure filter logic**

Create `apps/web/src/lib/vocabFilters.ts`:

```ts
import type { VocabRecord } from "./vocabRecords";

export interface VocabFilterState {
  dueOnly: boolean;
  topicIds: Set<string>;
  cefrLevels: Set<string>;
}

export function isFilterActive(filters: VocabFilterState): boolean {
  return filters.dueOnly || filters.topicIds.size > 0 || filters.cefrLevels.size > 0;
}

export function matchesFilters(
  record: VocabRecord,
  filters: VocabFilterState,
  isDue: (record: VocabRecord) => boolean
): boolean {
  if (filters.dueOnly && !isDue(record)) return false;
  if (filters.topicIds.size > 0 && !record.topicIds.some((id) => filters.topicIds.has(id))) {
    return false;
  }
  if (filters.cefrLevels.size > 0 && !filters.cefrLevels.has(record.cefrLevel)) {
    return false;
  }
  return true;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Wire multi-select state into the Vocab Bank page**

Modify `apps/web/src/app/(app)/vocab-bank/page.tsx`. Update the imports:

```tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { deleteVocabRecord, getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { formatDueLabel } from "@/lib/vocabDisplay";
import { isFilterActive, matchesFilters, type VocabFilterState } from "@/lib/vocabFilters";
import { SignInButton } from "@/components/SignInButton";
import { VocabDrawer } from "@/components/vocab-bank/VocabDrawer";
```

Remove the `type FilterKey = ...` line entirely, and replace the `filter` state declaration:

```tsx
  const [dueOnly, setDueOnly] = useState(false);
  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [selectedCefrLevels, setSelectedCefrLevels] = useState<Set<string>>(new Set());
```

Replace the `filtered` useMemo:

```tsx
  const filters: VocabFilterState = { dueOnly, topicIds: selectedTopicIds, cefrLevels: selectedCefrLevels };
  const filterActive = isFilterActive(filters);

  const filtered = useMemo(() => {
    if (!records) return [];
    return records.filter((r) => matchesFilters(r, filters, isDue));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [records, dueOnly, selectedTopicIds, selectedCefrLevels, now]);
```

Add toggle/reset handlers right after the `filtered` block:

```tsx
  const toggleTopic = (id: string) => {
    setSelectedTopicIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleCefr = (level: string) => {
    setSelectedCefrLevels((prev) => {
      const next = new Set(prev);
      if (next.has(level)) next.delete(level);
      else next.add(level);
      return next;
    });
  };

  const clearFilters = () => {
    setDueOnly(false);
    setSelectedTopicIds(new Set());
    setSelectedCefrLevels(new Set());
  };
```

Replace the `.vb-toolbar` block:

```tsx
      <div className="vb-toolbar">
        <button className={`vb-chip${!filterActive ? " active" : ""}`} onClick={clearFilters}>
          Tất cả ({records.length})
        </button>
        <button className={`vb-chip${dueOnly ? " active" : ""}`} onClick={() => setDueOnly((v) => !v)}>
          Cần ôn hôm nay ({records.filter(isDue).length})
        </button>
        {topicChips.map((t) => (
          <button
            key={t.id}
            className={`vb-chip${selectedTopicIds.has(t.id) ? " active" : ""}`}
            onClick={() => toggleTopic(t.id)}
          >
            {t.name}
          </button>
        ))}
        {cefrChips.map((level) => (
          <button
            key={level}
            className={`vb-chip${selectedCefrLevels.has(level) ? " active" : ""}`}
            onClick={() => toggleCefr(level)}
          >
            {level.toUpperCase()}
          </button>
        ))}
        {filterActive && (
          <button className="vb-chip vb-chip-clear" onClick={clearFilters}>
            ✕ Xoá lọc
          </button>
        )}
      </div>
```

- [ ] **Step 6: Add the clear-chip CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.vb-chip-clear {
  color: var(--danger);
  border-color: var(--danger);
  background: var(--danger-bg);
}
```

- [ ] **Step 7: Update and extend the page tests**

Modify `apps/web/src/app/(app)/vocab-bank/page.test.tsx` — the existing "filters to due-today words when that chip is clicked" test (clicking the `"Cần ôn hôm nay (1)"` button) still passes unchanged since the button's visible text/behavior are the same. Add these new test cases inside the existing `describe("VocabBankPage", ...)` block (needs 3 records to exercise multi-select — add a third fixture and use it only in these new tests):

```tsx
const RECORD_TRAVEL_A1 = {
  ...RECORD_DUE_TODAY,
  id: "3",
  headword: "passport",
  meaning: "hộ chiếu",
  topicIds: ["travel"],
  cefrLevel: "a1",
  nextReviewAt: "2099-01-01T00:00:00.000Z",
};
```

```tsx
  it("OR-combines multiple CEFR chips within the same facet", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(
      [RECORD_DUE_TODAY, RECORD_NOT_DUE, RECORD_TRAVEL_A1] as never
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate"); // b2
    await screen.findByText("meticulous"); // c1
    await screen.findByText("passport"); // a1

    fireEvent.click(screen.getByText("B2"));
    fireEvent.click(screen.getByText("C1"));

    expect(screen.getByText("relocate")).toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.queryByText("passport")).not.toBeInTheDocument();
  });

  it("AND-combines across facets (topic AND cefr)", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(
      [RECORD_DUE_TODAY, RECORD_NOT_DUE, RECORD_TRAVEL_A1] as never
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    fireEvent.click(screen.getByText("Business")); // RECORD_DUE_TODAY + RECORD_NOT_DUE both "business"
    fireEvent.click(screen.getByText("C1")); // only RECORD_NOT_DUE is c1

    expect(screen.queryByText("relocate")).not.toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.queryByText("passport")).not.toBeInTheDocument();
  });

  it("shows Xoá lọc only when a filter is active, and it resets everything", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    expect(screen.queryByText("✕ Xoá lọc")).not.toBeInTheDocument();

    fireEvent.click(screen.getByText("C1"));
    expect(screen.getByText("✕ Xoá lọc")).toBeInTheDocument();
    expect(screen.queryByText("relocate")).not.toBeInTheDocument();

    fireEvent.click(screen.getByText("✕ Xoá lọc"));
    expect(screen.queryByText("✕ Xoá lọc")).not.toBeInTheDocument();
    expect(screen.getByText("relocate")).toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
  });
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/lib/vocabFilters.ts apps/web/src/lib/vocabFilters.test.ts "apps/web/src/app/(app)/vocab-bank" apps/web/src/styles/bloom.css
git commit -m "feat(web): multi-select Vocab Bank filters (OR within facet, AND across facets)"
```

---

## Task 3: `usePaginatedScroll` hook (generic, client-side, cached)

**Files:**
- Create: `apps/web/src/lib/usePaginatedScroll.ts`
- Create: `apps/web/src/lib/usePaginatedScroll.test.tsx`

**Interfaces:**
- Produces: `usePaginatedScroll<T>(items: T[])` returning `{ visibleItems: T[], totalPages: number, currentPage: number, containerRef: RefObject<HTMLDivElement>, sentinelRef: RefObject<HTMLDivElement>, jumpToPage: (page: number) => void }`. Used by Task 4.
- **Contract the consumer must follow:** the item rows rendered from `visibleItems` must be the first `visibleItems.length` children of the element `containerRef` is attached to, in order, with the element `sentinelRef` is attached to appended immediately after them as the next sibling. `jumpToPage` and the scroll-to-page behavior rely on positional `container.children[index]` lookup.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/lib/usePaginatedScroll.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
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
    this.callback([{ isIntersecting } as IntersectionObserverEntry], this as never);
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
    screen.getByText("page-3").click();
    expect(screen.getByText("item-24")).toBeInTheDocument();
    expect(Element.prototype.scrollIntoView).toHaveBeenCalled();
  });

  it("jumpToPage scrolls immediately when the target page is already revealed", () => {
    render(<TestList items={ITEMS} />);
    FakeIntersectionObserver.instances[0]?.trigger(true); // reveal page 2 (20 visible)
    vi.mocked(Element.prototype.scrollIntoView).mockClear();
    screen.getByText("page-1").click();
    expect(Element.prototype.scrollIntoView).toHaveBeenCalledTimes(1);
    // still 20 visible, no extra reveal happened
    expect(screen.getByText("item-19")).toBeInTheDocument();
  });

  it("resets to the first page when the item list changes", () => {
    const { rerender } = render(<TestList items={ITEMS} />);
    FakeIntersectionObserver.instances[0]?.trigger(true);
    expect(screen.getByTestId("page-info")).toHaveTextContent("2/3");

    const NEW_ITEMS = Array.from({ length: 5 }, (_, i) => `new-${i}`);
    rerender(<TestList items={NEW_ITEMS} />);
    expect(screen.getByTestId("page-info")).toHaveTextContent("1/1");
    expect(screen.getByText("new-0")).toBeInTheDocument();
    expect(screen.getByText("new-4")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./usePaginatedScroll` does not exist.

- [ ] **Step 3: Implement the hook**

Create `apps/web/src/lib/usePaginatedScroll.ts`:

```ts
"use client";

import { useEffect, useRef, useState } from "react";

const PAGE_SIZE = 10;

export function usePaginatedScroll<T>(items: T[]) {
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const pendingScrollPageRef = useRef<number | null>(null);

  // A new filtered item set (different array reference) restarts pagination
  // from the first page — this only fires on a genuine filter/data change,
  // not on every render, because `filtered` is itself a useMemo result.
  useEffect(() => {
    setVisibleCount(PAGE_SIZE);
  }, [items]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    const container = containerRef.current;
    if (!sentinel || !container) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          setVisibleCount((prev) => Math.min(prev + PAGE_SIZE, items.length));
        }
      },
      { root: container, threshold: 0.1 }
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [items.length]);

  const totalPages = Math.max(1, Math.ceil(items.length / PAGE_SIZE));
  const currentPage = Math.max(1, Math.ceil(Math.min(visibleCount, items.length) / PAGE_SIZE));

  const scrollToPage = (page: number) => {
    const container = containerRef.current;
    if (!container) return;
    const rowIndex = (page - 1) * PAGE_SIZE;
    const rowEl = container.children[rowIndex] as HTMLElement | undefined;
    rowEl?.scrollIntoView({ block: "start" });
  };

  const jumpToPage = (page: number) => {
    const clamped = Math.min(Math.max(page, 1), totalPages);
    const neededCount = Math.min(clamped * PAGE_SIZE, items.length);
    if (neededCount > visibleCount) {
      pendingScrollPageRef.current = clamped;
      setVisibleCount(neededCount);
    } else {
      scrollToPage(clamped);
    }
  };

  useEffect(() => {
    if (pendingScrollPageRef.current !== null) {
      const page = pendingScrollPageRef.current;
      pendingScrollPageRef.current = null;
      scrollToPage(page);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visibleCount]);

  return {
    visibleItems: items.slice(0, visibleCount),
    totalPages,
    currentPage,
    containerRef,
    sentinelRef,
    jumpToPage,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/usePaginatedScroll.ts apps/web/src/lib/usePaginatedScroll.test.tsx
git commit -m "feat(web): add usePaginatedScroll — generic client-side cached pagination hook"
```

---

## Task 4: Wire pagination into the Vocab Bank list + page-number bar

**Files:**
- Modify: `apps/web/src/app/(app)/vocab-bank/page.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `usePaginatedScroll` (`@/lib/usePaginatedScroll`).

- [ ] **Step 1: Write the failing tests**

Add to `apps/web/src/app/(app)/vocab-bank/page.test.tsx`, first add this helper near the top (after the existing fixtures, before `describe`):

```tsx
const MANY_RECORDS = Array.from({ length: 15 }, (_, i) => ({
  ...RECORD_DUE_TODAY,
  id: `many-${i}`,
  headword: `word-${i}`,
  meaning: `nghĩa-${i}`,
}));
```

Add near the top of the file (jsdom needs these stubbed for `usePaginatedScroll`, same pattern as its own test):

```tsx
beforeEach(() => {
  vi.clearAllMocks();
  Element.prototype.scrollIntoView = vi.fn();
  class FakeIntersectionObserver {
    observe = vi.fn();
    disconnect = vi.fn();
    unobserve = vi.fn();
    constructor(_callback: IntersectionObserverCallback) {}
  }
  vi.stubGlobal("IntersectionObserver", FakeIntersectionObserver as never);
});
```

(This replaces the existing `beforeEach(() => { vi.clearAllMocks(); });` block — merge the two so there's exactly one `beforeEach`.)

Add these test cases inside `describe("VocabBankPage", ...)`:

```tsx
  it("only renders the first 10 rows when more than 10 records match, and shows a page bar", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(MANY_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("word-0");

    expect(screen.getByText("word-9")).toBeInTheDocument();
    expect(screen.queryByText("word-10")).not.toBeInTheDocument();
    expect(screen.getByText("2")).toBeInTheDocument(); // page bar button for page 2
  });

  it("reveals more rows when the page-2 button is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(MANY_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("word-0");

    fireEvent.click(screen.getByText("2"));

    expect(screen.getByText("word-14")).toBeInTheDocument();
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — all 15 rows currently render at once, no page bar exists.

- [ ] **Step 3: Wire the hook into the page**

Modify `apps/web/src/app/(app)/vocab-bank/page.tsx`. Add to the imports:

```tsx
import { usePaginatedScroll } from "@/lib/usePaginatedScroll";
```

Add right after the `filtered` useMemo block:

```tsx
  const { visibleItems, totalPages, currentPage, containerRef, sentinelRef, jumpToPage } =
    usePaginatedScroll(filtered);
```

Replace the `.vb-list-wrap` block (inside `.vb-shell`) — change `filtered.map` to `visibleItems.map`, attach `containerRef`, and add the sentinel:

```tsx
        <div className="vb-list-wrap" ref={containerRef}>
          {filtered.length === 0 && <p>Không có từ nào phù hợp.</p>}
          {visibleItems.map((r) => (
            <div
              key={r.id}
              className={`vrow${r.id === selectedId ? " selected" : ""}`}
              onClick={() => setSelectedId(r.id)}
              role="button"
              tabIndex={0}
            >
              <span className="dot">{r.cefrLevel.toUpperCase()}</span>
              <span className="word">{r.headword}</span>
              <span className="meaning">{r.meaning}</span>
              <span className="due">{formatDueLabel(r.nextReviewAt, now)}</span>
            </div>
          ))}
          <div ref={sentinelRef} style={{ height: 1 }} />
        </div>
```

Add the page-number bar as a new sibling right after the closing `</div>` of `.vb-shell` (still inside the outer fragment, after `.vb-shell` closes):

```tsx
      {totalPages > 1 && (
        <div className="vb-pagination">
          {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => (
            <button
              key={page}
              className={`vb-page-btn${page === currentPage ? " active" : ""}`}
              onClick={() => jumpToPage(page)}
            >
              {page}
            </button>
          ))}
        </div>
      )}
```

- [ ] **Step 4: Append the scroll-container and pagination-bar CSS**

Modify `apps/web/src/styles/bloom.css`. Find the existing `.vb-list-wrap` rule and add two properties to it so it reads:

```css
.vb-list-wrap {
  flex: 1;
  min-width: 0;
  padding: 6px;
  max-height: 560px;
  overflow-y: auto;
}
```

Then append at the end of the file:

```css

.vb-pagination {
  display: flex;
  gap: 6px;
  justify-content: center;
  flex-wrap: wrap;
  padding: 12px 0 0;
}

.vb-page-btn {
  min-width: 30px;
  height: 30px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: var(--surface-2);
  color: var(--ink-soft);
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
}

.vb-page-btn.active {
  background: var(--accent);
  border-color: var(--accent);
  color: var(--accent-ink);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — full suite green, including all of Task 2's and Phase A's existing Vocab Bank tests (records counts like "2" total records never trigger pagination since 2 < 10).

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/vocab-bank" apps/web/src/styles/bloom.css
git commit -m "feat(web): paginate the Vocab Bank list with a scrollable container and page bar"
```

---

## Task 5: `updateVocabRecord` Firestore write

**Files:**
- Modify: `apps/web/src/lib/vocabRecords.ts`
- Modify: `apps/web/src/lib/vocabRecords.test.ts`

**Interfaces:**
- Produces: `VocabRecordUpdate` type (`Pick<VocabRecord, "meaning" | "examples" | "topicIds" | "personalNotes">`), `updateVocabRecord(uid, id, updates): Promise<void>`. Used by Task 6 and Task 7.

- [ ] **Step 1: Write the failing test**

Modify `apps/web/src/lib/vocabRecords.test.ts` — add `updateDoc: vi.fn()` to the existing `vi.mock("firebase/firestore", ...)` factory so it reads:

```ts
vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  doc: vi.fn(() => "mock-doc-ref"),
  deleteDoc: vi.fn(),
  updateDoc: vi.fn(),
  getDocs: vi.fn(),
  orderBy: vi.fn(() => "mock-order-by"),
  query: vi.fn(() => "mock-query"),
}));
```

Add this import at the top alongside the existing ones:

```ts
import { deleteDoc, doc, getDocs, orderBy, query, updateDoc } from "firebase/firestore";
```

(replacing the existing `import { deleteDoc, doc, getDocs, orderBy, query } from "firebase/firestore";` line)

Add this import:

```ts
import { countVocabRecords, deleteVocabRecord, getVocabRecords, updateVocabRecord } from "./vocabRecords";
```

(replacing the existing `import { countVocabRecords, deleteVocabRecord, getVocabRecords } from "./vocabRecords";` line)

Append this test:

```ts
describe("updateVocabRecord", () => {
  it("updates the editable fields plus updatedAt, by document id", async () => {
    await updateVocabRecord("user-123", "abc", {
      meaning: "nghĩa mới",
      examples: ["ví dụ mới"],
      topicIds: ["business"],
      personalNotes: "ghi chú",
    });

    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records", "abc");
    expect(updateDoc).toHaveBeenCalledWith(
      "mock-doc-ref",
      expect.objectContaining({
        meaning: "nghĩa mới",
        examples: ["ví dụ mới"],
        topicIds: ["business"],
        personalNotes: "ghi chú",
        updatedAt: expect.any(String),
      })
    );
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `updateVocabRecord` not exported yet.

- [ ] **Step 3: Implement**

Modify `apps/web/src/lib/vocabRecords.ts` — update the import line:

```ts
import { collection, deleteDoc, doc, getDocs, orderBy, query, updateDoc } from "firebase/firestore";
```

Add after the `VocabRecord` interface:

```ts
export type VocabRecordUpdate = Pick<VocabRecord, "meaning" | "examples" | "topicIds" | "personalNotes">;
```

Add after `deleteVocabRecord`:

```ts
export async function updateVocabRecord(
  uid: string,
  id: string,
  updates: VocabRecordUpdate
): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, "vocab_records", id);
  await updateDoc(ref, { ...updates, updatedAt: new Date().toISOString() });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/vocabRecords.ts apps/web/src/lib/vocabRecords.test.ts
git commit -m "feat(web): add updateVocabRecord Firestore write"
```

---

## Task 6: EditVocabModal component

**Files:**
- Create: `apps/web/src/components/vocab-bank/EditVocabModal.tsx`
- Create: `apps/web/src/components/vocab-bank/EditVocabModal.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `VocabRecord` (`@/lib/vocabRecords`), `VocabRecordUpdate` (`@/lib/vocabRecords`), `Topic` (`@/lib/topics`).
- Produces: `<EditVocabModal record topics onClose onSave />` where `onSave: (updates: VocabRecordUpdate) => Promise<void>`. Used by Task 7.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/components/vocab-bank/EditVocabModal.test.tsx`:

```tsx
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./EditVocabModal` does not exist.

- [ ] **Step 3: Implement**

Create `apps/web/src/components/vocab-bank/EditVocabModal.tsx`:

```tsx
"use client";

import { useState } from "react";
import type { Topic } from "@/lib/topics";
import type { VocabRecord, VocabRecordUpdate } from "@/lib/vocabRecords";

interface EditVocabModalProps {
  record: VocabRecord;
  topics: Topic[];
  onClose: () => void;
  onSave: (updates: VocabRecordUpdate) => Promise<void>;
}

const MAX_TOPICS = 2;

export function EditVocabModal({ record, topics, onClose, onSave }: EditVocabModalProps) {
  const [meaning, setMeaning] = useState(record.meaning);
  const [examples, setExamples] = useState<string[]>(record.examples);
  const [topicIds, setTopicIds] = useState<string[]>(record.topicIds);
  const [personalNotes, setPersonalNotes] = useState(record.personalNotes);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const toggleTopic = (id: string) => {
    setTopicIds((prev) => {
      if (prev.includes(id)) return prev.filter((t) => t !== id);
      if (prev.length >= MAX_TOPICS) return prev;
      return [...prev, id];
    });
  };

  const updateExample = (index: number, value: string) => {
    setExamples((prev) => prev.map((ex, i) => (i === index ? value : ex)));
  };

  const removeExample = (index: number) => {
    setExamples((prev) => prev.filter((_, i) => i !== index));
  };

  const addExample = () => {
    setExamples((prev) => [...prev, ""]);
  };

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    try {
      await onSave({
        meaning: meaning.trim(),
        examples: examples.map((ex) => ex.trim()).filter((ex) => ex.length > 0),
        topicIds,
        personalNotes: personalNotes.trim(),
      });
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : String(err));
      setSaving(false);
    }
  };

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal"
        role="dialog"
        aria-label={`Sửa từ ${record.headword}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="modal-header">
          <h3>Sửa &quot;{record.headword}&quot;</h3>
          <button className="closex" onClick={onClose} aria-label="Đóng">
            ✕
          </button>
        </div>
        <div className="modal-body">
          {error && <p role="alert">Lỗi lưu: {error}</p>}
          <label className="modal-field">
            <span>Nghĩa</span>
            <input value={meaning} onChange={(e) => setMeaning(e.target.value)} />
          </label>
          <div className="modal-field">
            <span>Ví dụ</span>
            {examples.map((ex, i) => (
              <div className="modal-example-row" key={i}>
                <input value={ex} onChange={(e) => updateExample(i, e.target.value)} />
                <button
                  type="button"
                  className="closex"
                  onClick={() => removeExample(i)}
                  aria-label="Xoá ví dụ"
                >
                  ✕
                </button>
              </div>
            ))}
            <button type="button" className="link-btn" onClick={addExample}>
              + Thêm ví dụ
            </button>
          </div>
          <div className="modal-field">
            <span>Chủ đề (tối đa {MAX_TOPICS})</span>
            <div className="chip-row">
              {topics.map((t) => (
                <button
                  type="button"
                  key={t.id}
                  className={`vb-chip${topicIds.includes(t.id) ? " active" : ""}`}
                  onClick={() => toggleTopic(t.id)}
                  disabled={!topicIds.includes(t.id) && topicIds.length >= MAX_TOPICS}
                >
                  {t.name}
                </button>
              ))}
            </div>
          </div>
          <label className="modal-field">
            <span>Ghi chú cá nhân</span>
            <textarea value={personalNotes} onChange={(e) => setPersonalNotes(e.target.value)} />
          </label>
        </div>
        <div className="modal-footer">
          <button onClick={onClose} disabled={saving}>
            Huỷ
          </button>
          <button className="save-btn" onClick={() => void handleSave()} disabled={saving}>
            {saving ? "Đang lưu…" : "Lưu"}
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Append the modal CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(54, 42, 51, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
}

.modal {
  background: var(--surface);
  border-radius: 20px;
  border: 1px solid var(--border);
  box-shadow: 0 32px 76px -36px rgba(120, 70, 90, 0.5);
  width: 480px;
  max-width: calc(100vw - 48px);
  max-height: calc(100vh - 96px);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.modal-header {
  padding: 18px 20px;
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-header h3 {
  margin: 0;
  font-size: 18px;
}

.modal-body {
  padding: 18px 20px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.modal-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 12.5px;
  color: var(--ink-soft);
  font-weight: 700;
}

.modal-field input,
.modal-field textarea {
  font-family: inherit;
  font-size: 14px;
  font-weight: 400;
  color: var(--ink);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 9px 12px;
  background: var(--surface-2);
}

.modal-field textarea {
  min-height: 70px;
  resize: vertical;
}

.modal-example-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.modal-example-row input {
  flex: 1;
}

.modal-field button.link-btn {
  align-self: flex-start;
  background: none;
  border: none;
  color: var(--accent);
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
  padding: 4px 0;
}

.vb-chip:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.modal-footer {
  padding: 14px 20px;
  border-top: 1px solid var(--border);
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

.modal-footer button {
  font-size: 13px;
  font-weight: 700;
  border-radius: 999px;
  padding: 9px 18px;
  cursor: pointer;
  border: 1px solid var(--border);
  background: var(--surface-2);
  color: var(--ink);
}

.modal-footer button.save-btn {
  background: var(--accent);
  border-color: var(--accent);
  color: var(--accent-ink);
}

.modal-footer button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/components/vocab-bank/EditVocabModal.tsx apps/web/src/components/vocab-bank/EditVocabModal.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add EditVocabModal component"
```

---

## Task 7: Wire "Sửa" to the edit modal and save flow

**Files:**
- Modify: `apps/web/src/components/vocab-bank/VocabDrawer.tsx`
- Modify: `apps/web/src/components/vocab-bank/VocabDrawer.test.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.test.tsx`

**Interfaces:**
- Consumes: `EditVocabModal` (`@/components/vocab-bank/EditVocabModal`), `updateVocabRecord`/`VocabRecordUpdate` (`@/lib/vocabRecords`).

- [ ] **Step 1: Update the failing VocabDrawer test**

Modify `apps/web/src/components/vocab-bank/VocabDrawer.test.tsx` — every `render(<VocabDrawer .../>)` call needs a new `onEdit={vi.fn()}` prop (currently only `record`/`topics`/`onClose`/`onDelete` are passed). Update each render call, e.g.:

```tsx
render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={vi.fn()} onEdit={vi.fn()} />);
```

Replace the existing `it("renders Sửa as disabled (deferred — no edit-flow mockup exists yet)", ...)` test with:

```tsx
  it("calls onEdit when Sửa is clicked", () => {
    const onEdit = vi.fn();
    render(
      <VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={vi.fn()} onEdit={onEdit} />
    );
    fireEvent.click(screen.getByRole("button", { name: "Sửa" }));
    expect(onEdit).toHaveBeenCalledOnce();
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `VocabDrawer` doesn't accept/use `onEdit` yet, "Sửa" is still disabled.

- [ ] **Step 3: Wire the button in VocabDrawer**

Modify `apps/web/src/components/vocab-bank/VocabDrawer.tsx` — update the props interface:

```tsx
interface VocabDrawerProps {
  record: VocabRecord;
  topics: Topic[];
  onClose: () => void;
  onDelete: () => void;
  onEdit: () => void;
}

export function VocabDrawer({ record, topics, onClose, onDelete, onEdit }: VocabDrawerProps) {
```

Replace the footer button block:

```tsx
          <div className="fa">
            <button onClick={onEdit}>Sửa</button>
            <button className="danger" onClick={onDelete}>
              Xoá
            </button>
          </div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS (VocabDrawer tests only — page.test.tsx will still fail until Step 5-6).

- [ ] **Step 5: Write the failing page-level edit tests**

Add to `apps/web/src/app/(app)/vocab-bank/page.test.tsx`:

```tsx
import { updateVocabRecord } from "@/lib/vocabRecords";
```

Update the existing `vi.mock("@/lib/vocabRecords", ...)` factory to include it:

```tsx
vi.mock("@/lib/vocabRecords", () => ({
  getVocabRecords: vi.fn(),
  deleteVocabRecord: vi.fn(),
  updateVocabRecord: vi.fn(),
}));
```

Add these test cases:

```tsx
  it("opens the edit modal from the drawer and saves changes in place", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(updateVocabRecord).mockResolvedValue(undefined);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("meticulous"));
    fireEvent.click(screen.getByRole("button", { name: "Sửa" }));

    expect(screen.getByRole("dialog")).toBeInTheDocument();

    fireEvent.change(screen.getByDisplayValue("tỉ mỉ, cẩn thận"), {
      target: { value: "nghĩa đã sửa" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(updateVocabRecord).toHaveBeenCalledWith("u1", "2", expect.any(Object)));
    await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
    expect(screen.getByText("nghĩa đã sửa")).toBeInTheDocument();
  });

  it("closes the edit modal without saving when Huỷ is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("meticulous"));
    fireEvent.click(screen.getByRole("button", { name: "Sửa" }));
    fireEvent.click(screen.getByRole("button", { name: "Huỷ" }));

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(updateVocabRecord).not.toHaveBeenCalled();
  });
```

Note: `RECORD_NOT_DUE` (id `"2"`, headword `"meticulous"`, meaning `"tỉ mỉ, cẩn thận"`) already exists as a fixture earlier in this file — reuse it, don't redefine it.

- [ ] **Step 6: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — no edit modal wired into the page yet.

- [ ] **Step 7: Wire the modal into the page**

Modify `apps/web/src/app/(app)/vocab-bank/page.tsx`. Replace the existing `import { deleteVocabRecord, getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";` line with:

```tsx
import {
  deleteVocabRecord,
  getVocabRecords,
  updateVocabRecord,
  type VocabRecord,
  type VocabRecordUpdate,
} from "@/lib/vocabRecords";
```

Add this new import line alongside the others:

```tsx
import { EditVocabModal } from "@/components/vocab-bank/EditVocabModal";
```

Add state right after the existing `deleteError` state:

```tsx
  const [editing, setEditing] = useState(false);
```

Add a handler right after `handleDelete`:

```tsx
  const handleUpdate = async (updates: VocabRecordUpdate) => {
    if (!user || !selected) return;
    await updateVocabRecord(user.uid, selected.id, updates);
    setRecords((prev) =>
      prev ? prev.map((r) => (r.id === selected.id ? { ...r, ...updates } : r)) : prev
    );
    setEditing(false);
  };
```

Replace the `<VocabDrawer>` render block to pass `onEdit`, and add the modal right after it (still inside `.vb-shell`'s parent, as a sibling — outside `.vb-shell` is fine since the modal is a fixed-position overlay):

```tsx
        {selected && (
          <VocabDrawer
            record={selected}
            topics={topics}
            onClose={() => setSelectedId(null)}
            onDelete={() => void handleDelete(selected.id)}
            onEdit={() => setEditing(true)}
          />
        )}
      </div>
      {editing && selected && (
        <EditVocabModal
          record={selected}
          topics={topics}
          onClose={() => setEditing(false)}
          onSave={handleUpdate}
        />
      )}
```

(This replaces the existing `{selected && (<VocabDrawer .../>)}\n      </div>` block — the closing `</div>` for `.vb-shell` now comes right after the `VocabDrawer` conditional, followed by the new `editing` conditional.)

- [ ] **Step 8: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — full suite green.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/components/vocab-bank "apps/web/src/app/(app)/vocab-bank"
git commit -m "feat(web): wire Sửa button to the edit modal with in-place save"
```

---

## Addendum (added after final whole-branch review + live user testing)

Tasks 8-10 below were added after Tasks 1-7 were implemented, reviewed, and tested live against the real 290-word Vocab Bank. They fix two real bugs the whole-branch review found (pagination silently resetting on save/delete, and the page bar's active state never decreasing) and one product-consistency gap the user found (topic filter silently limited to ~7 of 20+ synced topics). See `docs/superpowers/specs/2026-08-15-vocab-bank-polish-design.md` §6 for the full design rationale, including the two options mocked and visually compared for the topic display (a popover was chosen).

**Additional Global Constraint for these 3 tasks:** the `usePaginatedScroll` test file's fake `IntersectionObserver` needs to support *multiple simultaneous instances* (the hook creates two: one watching the reveal sentinel, one watching per-page marker rows for scroll tracking) — tests must trigger the correct instance for a given target element, not assume a single global instance.

---

## Task 8: Fix pagination reset-on-mutation + track real scroll position

**Files:**
- Modify: `apps/web/src/lib/usePaginatedScroll.ts`
- Modify: `apps/web/src/lib/usePaginatedScroll.test.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.tsx`

**Interfaces:**
- `usePaginatedScroll<T>` gains a required second parameter, `resetKey: string | number`. Its returned `currentPage` now reflects the row actually visible on screen (via a second `IntersectionObserver`), not "how much has been revealed so far". Everything else about its return shape (`visibleItems`, `totalPages`, `containerRef`, `sentinelRef`, `jumpToPage`) is unchanged.
- Produces: the DOM contract (rows as the first N children of the container, sentinel as the next sibling) is **unchanged** — the new scroll-tracking observer reads `container.children` positionally, exactly like the existing `scrollToPage` already does. No new elements, no `data-*` attributes required from the consumer.

**Bugs being fixed (both empirically confirmed by the whole-branch review):**
1. The hook reset `visibleCount` whenever the `items` array got a new reference (`useEffect(..., [items])`). But `filtered` (passed as `items`) gets a new array reference on *every* `setRecords` call, including a successful edit or delete — not just when the user changes a filter. Result: saving an edit or deleting a word from page 12 of 29 silently snapped the list back to page 1.
2. `currentPage` was derived from `visibleCount` (`Math.ceil(min(visibleCount, items.length) / PAGE_SIZE)`), which only ever increases (revealing more never un-reveals). Clicking page 1 after having scrolled to page 3 left the page bar showing page 3 as active, because `visibleCount` never went down.

- [ ] **Step 1: Write the failing tests**

Replace `apps/web/src/lib/usePaginatedScroll.test.tsx` entirely:

```tsx
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `usePaginatedScroll` doesn't accept a second argument yet, and doesn't do real scroll tracking.

- [ ] **Step 3: Implement**

Replace `apps/web/src/lib/usePaginatedScroll.ts` entirely:

```ts
"use client";

import { useEffect, useRef, useState } from "react";

const PAGE_SIZE = 10;

export function usePaginatedScroll<T>(items: T[], resetKey: string | number) {
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);
  const [viewedPage, setViewedPage] = useState(1);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const pendingScrollPageRef = useRef<number | null>(null);

  // Resets only on a genuine filter change (the caller-provided resetKey),
  // not on every `items` array identity change — `filtered` gets a new
  // array reference on every save/delete too, and those must NOT collapse
  // the list back to page 1.
  useEffect(() => {
    setVisibleCount(PAGE_SIZE);
    setViewedPage(1);
  }, [resetKey]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    const container = containerRef.current;
    if (!sentinel || !container) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          setVisibleCount((prev) => Math.min(prev + PAGE_SIZE, items.length));
        }
      },
      { root: container, threshold: 0.1 }
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [items.length]);

  // Real scroll-position tracking: watch the first row of each revealed
  // page-group so the page bar's "active" state reflects what's actually
  // visible, not just "how much has been revealed so far".
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const pageByElement = new Map<Element, number>();
    const rows = Array.from(container.children).slice(0, visibleCount);
    rows.forEach((row, i) => {
      if (i % PAGE_SIZE === 0) {
        pageByElement.set(row, Math.floor(i / PAGE_SIZE) + 1);
      }
    });

    const observer = new IntersectionObserver(
      (entries) => {
        let best: number | null = null;
        for (const entry of entries) {
          if (entry.isIntersecting) {
            const page = pageByElement.get(entry.target);
            if (page !== undefined && (best === null || page > best)) best = page;
          }
        }
        if (best !== null) setViewedPage(best);
      },
      { root: container, threshold: 0, rootMargin: "0px 0px -85% 0px" }
    );

    pageByElement.forEach((_, el) => observer.observe(el));
    return () => observer.disconnect();
  }, [visibleCount]);

  const totalPages = Math.max(1, Math.ceil(items.length / PAGE_SIZE));

  const scrollToPage = (page: number) => {
    const container = containerRef.current;
    if (!container) return;
    const rowIndex = (page - 1) * PAGE_SIZE;
    const rowEl = container.children[rowIndex] as HTMLElement | undefined;
    rowEl?.scrollIntoView({ block: "start" });
  };

  const jumpToPage = (page: number) => {
    const clamped = Math.min(Math.max(page, 1), totalPages);
    const neededCount = Math.min(clamped * PAGE_SIZE, items.length);
    // Optimistic: the scroll-tracking observer above corrects this if the
    // user then scrolls manually, but the click should feel instant.
    setViewedPage(clamped);
    if (neededCount > visibleCount) {
      pendingScrollPageRef.current = clamped;
      setVisibleCount(neededCount);
    } else {
      scrollToPage(clamped);
    }
  };

  useEffect(() => {
    if (pendingScrollPageRef.current !== null) {
      const page = pendingScrollPageRef.current;
      pendingScrollPageRef.current = null;
      scrollToPage(page);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visibleCount]);

  return {
    visibleItems: items.slice(0, visibleCount),
    totalPages,
    currentPage: viewedPage,
    containerRef,
    sentinelRef,
    jumpToPage,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Pass a filter-identity resetKey from the Vocab Bank page**

Modify `apps/web/src/app/(app)/vocab-bank/page.tsx` — replace the hook call:

```tsx
  const filterSignature = `${dueOnly}|${Array.from(selectedTopicIds).sort().join(",")}|${Array.from(
    selectedCefrLevels
  ).sort().join(",")}`;

  const { visibleItems, totalPages, currentPage, containerRef, sentinelRef, jumpToPage } =
    usePaginatedScroll(filtered, filterSignature);
```

(This replaces the existing `const { visibleItems, totalPages, currentPage, containerRef, sentinelRef, jumpToPage } = usePaginatedScroll(filtered);` line — same destructured variables, now with the second `filterSignature` argument.)

- [ ] **Step 6: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — full suite green, including the existing 2-record and 15-record Vocab Bank page tests (both stay well under a filter change during their scenarios, so this change is invisible to them).

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/lib/usePaginatedScroll.ts apps/web/src/lib/usePaginatedScroll.test.tsx "apps/web/src/app/(app)/vocab-bank/page.tsx"
git commit -m "fix(web): stop pagination resetting on save/delete, track real scroll position"
```

---

## Task 9: Topic filter — show all synced topics via a popover

**Files:**
- Create: `apps/web/src/components/vocab-bank/TopicFilterPopover.tsx`
- Create: `apps/web/src/components/vocab-bank/TopicFilterPopover.test.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Produces: `<TopicFilterPopover topics={Topic[]} selectedTopicIds={Set<string>} onApply={(ids: Set<string>) => void} />`. Committing a selection only happens on "Áp dụng" — toggling chips inside the open popover updates a local draft, not the parent's state, until applied.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/components/vocab-bank/TopicFilterPopover.test.tsx`:

```tsx
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./TopicFilterPopover` does not exist.

- [ ] **Step 3: Implement**

Create `apps/web/src/components/vocab-bank/TopicFilterPopover.tsx`:

```tsx
"use client";

import { useState } from "react";
import type { Topic } from "@/lib/topics";

interface TopicFilterPopoverProps {
  topics: Topic[];
  selectedTopicIds: Set<string>;
  onApply: (ids: Set<string>) => void;
}

export function TopicFilterPopover({ topics, selectedTopicIds, onApply }: TopicFilterPopoverProps) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<Set<string>>(new Set(selectedTopicIds));

  const openPopover = () => {
    setDraft(new Set(selectedTopicIds));
    setOpen(true);
  };

  const toggleDraft = (id: string) => {
    setDraft((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const apply = () => {
    onApply(draft);
    setOpen(false);
  };

  const label = selectedTopicIds.size > 0 ? `Chủ đề ▾ (${selectedTopicIds.size})` : "Chủ đề ▾";

  return (
    <div className="vb-topic-popover-wrap">
      <button
        type="button"
        className={`vb-chip${selectedTopicIds.size > 0 ? " active" : ""}`}
        onClick={() => (open ? setOpen(false) : openPopover())}
      >
        {label}
      </button>
      {open && (
        <div className="vb-topic-popover" role="dialog" aria-label="Chọn chủ đề">
          <div className="vb-topic-popover-opts">
            {topics.map((t) => (
              <button
                type="button"
                key={t.id}
                className={`vb-chip${draft.has(t.id) ? " active" : ""}`}
                onClick={() => toggleDraft(t.id)}
              >
                {t.emoji} {t.name}
              </button>
            ))}
          </div>
          <button type="button" className="vb-topic-popover-apply" onClick={apply}>
            Áp dụng
          </button>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Wire it into the Vocab Bank page, replacing the "only topics with saved words" chip row**

Modify `apps/web/src/app/(app)/vocab-bank/page.tsx`. Add the import:

```tsx
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
```

Delete the `topicChips` useMemo block entirely (it computed "topics that have ≥1 saved word" — no longer used; the popover now takes the full `topics` state directly).

Delete the `toggleTopic` function entirely (the popover owns its own toggle-then-apply flow now; nothing else in the file calls `toggleTopic`).

Replace the `{topicChips.map((t) => (...))}` block in the toolbar with:

```tsx
        <TopicFilterPopover topics={topics} selectedTopicIds={selectedTopicIds} onApply={setSelectedTopicIds} />
```

- [ ] **Step 6: Append the popover CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.vb-topic-popover-wrap {
  position: relative;
  display: inline-block;
}

.vb-topic-popover {
  position: absolute;
  top: calc(100% + 8px);
  left: 0;
  width: 320px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 14px;
  box-shadow: 0 18px 40px -14px rgba(54, 42, 51, 0.35);
  z-index: 10;
}

.vb-topic-popover-opts {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
  margin-bottom: 12px;
  max-height: 220px;
  overflow-y: auto;
}

.vb-topic-popover-apply {
  width: 100%;
  font-size: 12.5px;
  font-weight: 700;
  background: var(--accent);
  color: var(--accent-ink);
  border: none;
  border-radius: 999px;
  padding: 9px 0;
  cursor: pointer;
}
```

- [ ] **Step 7: Update the page test that exercised the old inline topic chips**

Modify `apps/web/src/app/(app)/vocab-bank/page.test.tsx` — replace the `"AND-combines across facets (topic AND cefr)"` test body with:

```tsx
  it("AND-combines across facets (topic AND cefr)", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(
      [RECORD_DUE_TODAY, RECORD_NOT_DUE, RECORD_TRAVEL_A1] as never
    );
    vi.mocked(getTopics).mockResolvedValue([TOPIC_BUSINESS] as never);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    fireEvent.click(screen.getByRole("button", { name: "Chủ đề ▾" }));
    fireEvent.click(screen.getByRole("button", { name: "💼 Business" }));
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    fireEvent.click(screen.getByRole("button", { name: "C1" })); // only RECORD_NOT_DUE is c1

    expect(screen.queryByText("relocate")).not.toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.queryByText("passport")).not.toBeInTheDocument();
  });
```

(`TOPIC_BUSINESS` is the existing fixture already defined earlier in this file — reuse it, don't redefine it. The `"OR-combines multiple CEFR chips..."` and `"shows Xoá lọc..."` tests are untouched — they only interact with CEFR chips, which stay as direct toolbar buttons.)

- [ ] **Step 8: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — full suite green.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/components/vocab-bank/TopicFilterPopover.tsx apps/web/src/components/vocab-bank/TopicFilterPopover.test.tsx "apps/web/src/app/(app)/vocab-bank" apps/web/src/styles/bloom.css
git commit -m "feat(web): show all synced topics via a filter popover, not just ones with saved words"
```

---

## Task 10: Windowed page-number bar

**Files:**
- Create: `apps/web/src/lib/pageWindow.ts`
- Create: `apps/web/src/lib/pageWindow.test.ts`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Produces: `getPageWindow(current: number, total: number): (number | "…")[]` — pure function, no React/DOM dependency. Pattern confirmed with the user: first page, last page, and ±2 pages around the current page, with `"…"` filling any gap (e.g. `getPageWindow(6, 29)` → `[1, "…", 4, 5, 6, 7, 8, "…", 29]`).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/lib/pageWindow.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { getPageWindow } from "./pageWindow";

describe("getPageWindow", () => {
  it("windows around a middle page with ellipses on both sides", () => {
    expect(getPageWindow(6, 29)).toEqual([1, "…", 4, 5, 6, 7, 8, "…", 29]);
  });

  it("has no leading ellipsis when near the first page", () => {
    expect(getPageWindow(1, 29)).toEqual([1, 2, 3, "…", 29]);
  });

  it("has no trailing ellipsis when near the last page", () => {
    expect(getPageWindow(29, 29)).toEqual([1, "…", 27, 28, 29]);
  });

  it("has no ellipses at all when every page already fits in the window", () => {
    expect(getPageWindow(1, 3)).toEqual([1, 2, 3]);
    expect(getPageWindow(2, 5)).toEqual([1, 2, 3, 4, 5]);
  });

  it("returns just [1] for a single page", () => {
    expect(getPageWindow(1, 1)).toEqual([1]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./pageWindow` does not exist.

- [ ] **Step 3: Implement**

Create `apps/web/src/lib/pageWindow.ts`:

```ts
const SIBLINGS = 2;

export function getPageWindow(current: number, total: number): (number | "…")[] {
  if (total <= 1) return total === 1 ? [1] : [];

  const left = Math.max(2, current - SIBLINGS);
  const right = Math.min(total - 1, current + SIBLINGS);

  const window: (number | "…")[] = [1];
  if (left > 2) window.push("…");
  for (let page = left; page <= right; page++) window.push(page);
  if (right < total - 1) window.push("…");
  window.push(total);

  return window;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Wire it into the page-number bar**

Modify `apps/web/src/app/(app)/vocab-bank/page.tsx`. Add the import:

```tsx
import { getPageWindow } from "@/lib/pageWindow";
```

Replace the `.vb-pagination` block:

```tsx
      {totalPages > 1 && (
        <div className="vb-pagination">
          {getPageWindow(currentPage, totalPages).map((page, i) =>
            page === "…" ? (
              <span className="vb-page-ellipsis" key={`ellipsis-${i}`}>
                …
              </span>
            ) : (
              <button
                key={page}
                className={`vb-page-btn${page === currentPage ? " active" : ""}`}
                onClick={() => jumpToPage(page)}
              >
                {page}
              </button>
            )
          )}
        </div>
      )}
```

- [ ] **Step 6: Append the ellipsis CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.vb-page-ellipsis {
  padding: 0 4px;
  color: var(--ink-faint);
  font-size: 12.5px;
  align-self: center;
}
```

- [ ] **Step 7: Add a test proving the bar is windowed for a large result set**

Modify `apps/web/src/app/(app)/vocab-bank/page.test.tsx` — add this fixture near `MANY_RECORDS`:

```tsx
const HUGE_RECORDS = Array.from({ length: 250 }, (_, i) => ({
  ...RECORD_DUE_TODAY,
  id: `huge-${i}`,
  headword: `w${i}`,
  meaning: `m${i}`,
}));
```

Add this test inside `describe("VocabBankPage", ...)`:

```tsx
  it("shows a windowed page bar (not all 25 buttons) for a large result set", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(HUGE_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("w0");

    // 250 records / 10 per page = 25 pages; windowed around page 1 -> 1, 2, 3, …, 25
    expect(screen.getByRole("button", { name: "1" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "2" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "3" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "25" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "13" })).not.toBeInTheDocument();
    expect(screen.getByText("…")).toBeInTheDocument();
  });
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — full suite green.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/lib/pageWindow.ts apps/web/src/lib/pageWindow.test.ts "apps/web/src/app/(app)/vocab-bank" apps/web/src/styles/bloom.css
git commit -m "feat(web): window the page-number bar instead of rendering every page"
```

---

## Final verification (whole plan, including the addendum)

- [ ] Run the full test suite: `npm --prefix apps/web test` — expect all tests (Phase A's + every test added in this plan, Tasks 1-10) to pass.
- [ ] Run typecheck: `npm --prefix apps/web run typecheck` — expect no errors.
- [ ] Run the production build: `npm --prefix apps/web run build` — expect a clean build.
- [ ] Manually verify against production Firebase: `npm --prefix apps/web run dev`, sign in, confirm the app frame now fills a wide browser window, confirm selecting multiple topic (via the new popover)/CEFR chips combines correctly (OR within a facet, AND across facets), confirm "Xoá lọc" appears/resets correctly, confirm scrolling the list reveals more rows and the page bar (now windowed) jumps correctly and its active state tracks real scroll position, confirm editing or deleting a real (throwaway, not important) word from a page other than page 1 does **not** snap the list back to page 1, and confirm editing a word via "Sửa" actually persists after a page reload (this also verifies Firestore security rules permit `update`, not just `read`/`delete` — the whole-branch review flagged this as unverified from source since no `firestore.rules` file exists in this repo).
