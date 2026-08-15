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
          setVisibleCount((prev) => {
            const next = Math.min(prev + PAGE_SIZE, items.length);
            if (next > prev) {
              // Optimistic: reaching the sentinel means the user has
              // scrolled past everything currently revealed, so treat the
              // newly revealed page as "current" — the scroll-tracking
              // observer below corrects this if they then scroll back up.
              setViewedPage(Math.ceil(next / PAGE_SIZE));
            }
            return next;
          });
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
