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
});
