"use client";

import { useEffect, useState } from "react";

/**
 * Unwraps a Next.js 16 dynamic-route `params` promise.
 *
 * Next 16 passes a page's `params` prop as `Promise<T>` (see
 * `apps/web/AGENTS.md` + `node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/dynamic-routes.md`).
 * React's `use()` is the documented way to unwrap it in a Client Component,
 * but it requires a Suspense boundary, and in this repo's Vitest + jsdom
 * test harness the Suspense retry never flushes even under `act()` (verified
 * with a minimal `use()` + `<Suspense>` repro that hung past a 5s timeout).
 * This hook blocks rendering until the params promise settles via a plain
 * effect instead, which resolves correctly under
 * `@testing-library/react`'s `findBy*`/`waitFor` polling and behaves
 * identically for a real (already-settled-by-request-time) params promise.
 */
export function useRouteParams<T>(params: Promise<T>): T | null {
  const [resolved, setResolved] = useState<T | null>(null);

  useEffect(() => {
    let cancelled = false;
    params.then((value) => {
      if (!cancelled) setResolved(value);
    });
    return () => {
      cancelled = true;
    };
  }, [params]);

  return resolved;
}
