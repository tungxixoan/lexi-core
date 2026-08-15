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
