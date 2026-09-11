import { act, renderHook, waitFor } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { useRouteParams } from "./useRouteParams";

describe("useRouteParams", () => {
  it("resolves the params promise", async () => {
    const { result } = renderHook(({ params }) => useRouteParams(params), {
      initialProps: { params: Promise.resolve({ id: "a" }) },
    });
    expect(result.current).toBeNull();
    await waitFor(() => expect(result.current).toEqual({ id: "a" }));
  });

  it("clears the previous value the instant params' identity changes, instead of showing the old route's value while the new promise is pending", async () => {
    let resolveSecond: (value: { id: string }) => void = () => {};
    const first = Promise.resolve({ id: "a" });
    const second = new Promise<{ id: string }>((resolve) => {
      resolveSecond = resolve;
    });

    const { result, rerender } = renderHook(({ params }) => useRouteParams(params), {
      initialProps: { params: first },
    });
    await waitFor(() => expect(result.current).toEqual({ id: "a" }));

    rerender({ params: second });
    // Must not still show note "a" under the new URL while "b" is pending —
    // this is the exact bug being regression-tested: a stale value from the
    // previous params identity must never leak into the new render.
    expect(result.current).toBeNull();

    await act(async () => {
      resolveSecond({ id: "b" });
      await second;
    });
    expect(result.current).toEqual({ id: "b" });
  });

  it("returns null on the very first render after params changes, before any effect can run", async () => {
    const renders: Array<{ id: string } | null> = [];
    let resolveSecond: (value: { id: string }) => void = () => {};
    const first = Promise.resolve({ id: "a" });
    const second = new Promise<{ id: string }>((resolve) => {
      resolveSecond = resolve;
    });

    const { rerender } = renderHook(
      ({ params }: { params: Promise<{ id: string }> }) => {
        const value = useRouteParams(params);
        renders.push(value);
        return value;
      },
      { initialProps: { params: first } },
    );

    await waitFor(() => expect(renders.at(-1)).toEqual({ id: "a" }));

    const countBeforeRerender = renders.length;
    rerender({ params: second });

    // The FIRST new entry pushed to `renders` after the params identity
    // changed reflects what committed to the DOM before any effect had a
    // chance to run. It must already be null: a "reset inside useEffect"
    // implementation would still show note "a"'s value here, because
    // `renderHook`'s `rerender` flushes effects (inside `act`) before
    // returning, which is exactly what let the old, buggier test pass
    // without catching this.
    expect(renders[countBeforeRerender]).toBeNull();

    await act(async () => {
      resolveSecond({ id: "b" });
      await second;
    });
    expect(renders.at(-1)).toEqual({ id: "b" });
  });

  it("settles on null, without an unhandled rejection, when the params promise rejects", async () => {
    const rejected = Promise.reject(new Error("boom"));
    const { result } = renderHook(({ params }) => useRouteParams(params), {
      initialProps: { params: rejected },
    });
    expect(result.current).toBeNull();

    await act(async () => {
      await rejected.catch(() => {});
    });
    expect(result.current).toBeNull();
  });
});
