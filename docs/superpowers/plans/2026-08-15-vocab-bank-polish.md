# Vocab Bank Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three follow-up enhancements to the already-shipped Vocab Bank screen: the app shell fills the full viewport width, filter chips become multi-select with a client-side cached/paginated scroll list, and vocab records become editable (meaning, examples, topics, notes) via a modal.

**Architecture:** All three pieces build directly on Plan 3 Phase A's existing files (`apps/web/src/app/(app)/vocab-bank/page.tsx`, `apps/web/src/components/vocab-bank/VocabDrawer.tsx`, `apps/web/src/lib/vocabRecords.ts`, `apps/web/src/styles/bloom.css`) — no new routes, no new Cloud Functions. Filtering and pagination both operate entirely on the already-fully-loaded in-memory `records` array (no new Firestore queries); only the new edit flow adds one new Firestore write (`updateVocabRecord`).

**Tech Stack:** Same as Plan 3 Phase A — Next.js 16 App Router, React 19, Firebase JS SDK v12 (`firebase/firestore`), Vitest + React Testing Library + jsdom.

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

## Final verification (whole plan)

- [ ] Run the full test suite: `npm --prefix apps/web test` — expect all tests (Phase A's + every test added in this plan) to pass.
- [ ] Run typecheck: `npm --prefix apps/web run typecheck` — expect no errors.
- [ ] Run the production build: `npm --prefix apps/web run build` — expect a clean build.
- [ ] Manually verify against production Firebase: `npm --prefix apps/web run dev`, sign in, confirm the app frame now fills a wide browser window, confirm selecting multiple topic/CEFR chips combines correctly (OR within a facet, AND across facets), confirm "Xoá lọc" appears/resets correctly, confirm scrolling the list reveals more rows and the page-number bar jumps correctly, and confirm editing a real (throwaway, not important) word via "Sửa" actually persists after a page reload.
