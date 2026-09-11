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
  const [state, setState] = useState<{ promise: Promise<T>; value: T | null }>({
    promise: params,
    value: null,
  });

  // Render-phase reset: if `params`' identity has changed since the last
  // committed state (e.g. navigating /note/a -> /note/b re-uses the same
  // component instance, no remount), treat the value as not-yet-resolved
  // immediately, during THIS render — not after an effect runs. Without
  // this, there is one commit where the OLD note's data renders under the
  // NEW url, because `useEffect` runs after paint. Matches `use()`'s
  // behavior of suspending immediately on a new pending promise.
  const resolved = state.promise === params ? state.value : null;

  useEffect(() => {
    let cancelled = false;
    if (state.promise !== params) {
      setState({ promise: params, value: null });
    }
    params.then(
      (value) => {
        if (!cancelled) setState({ promise: params, value });
      },
      () => {
        // A rejected params promise leaves `resolved` as null (the
        // loading/not-found state pages already render) instead of an
        // unhandled promise rejection.
      },
    );
    return () => {
      cancelled = true;
    };
  }, [params, state.promise]);

  return resolved;
}
