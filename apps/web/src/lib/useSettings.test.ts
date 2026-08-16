import { describe, expect, it, vi } from "vitest";
import { renderHook, waitFor, act } from "@testing-library/react";
import { useSettings } from "./useSettings";
import { getSettings, saveSettings, DEFAULT_SETTINGS } from "./settings";

vi.mock("./settings", async () => {
  const actual = await vi.importActual<typeof import("./settings")>("./settings");
  return {
    ...actual,
    getSettings: vi.fn(),
    saveSettings: vi.fn(),
  };
});

describe("useSettings", () => {
  it("returns DEFAULT_SETTINGS immediately with loading=false when uid is null (logged out)", async () => {
    const { result } = renderHook(() => useSettings(null));
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.settings).toEqual(DEFAULT_SETTINGS);
    expect(getSettings).not.toHaveBeenCalled();
  });

  it("loads settings for a real uid", async () => {
    const loaded = { ...DEFAULT_SETTINGS, theme: "dark" as const };
    vi.mocked(getSettings).mockResolvedValue(loaded);

    const { result } = renderHook(() => useSettings("user-123"));

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(getSettings).toHaveBeenCalledWith("user-123");
    expect(result.current.settings).toEqual(loaded);
    expect(result.current.error).toBeNull();
  });

  it("sets error when getSettings rejects", async () => {
    vi.mocked(getSettings).mockRejectedValue(new Error("offline"));
    const { result } = renderHook(() => useSettings("user-123"));
    await waitFor(() => expect(result.current.error).toBe("offline"));
  });

  it("save() persists via saveSettings and updates local state once the write succeeds", async () => {
    vi.mocked(getSettings).mockResolvedValue(DEFAULT_SETTINGS);
    vi.mocked(saveSettings).mockResolvedValue(undefined);
    const { result } = renderHook(() => useSettings("user-123"));
    await waitFor(() => expect(result.current.loading).toBe(false));

    const next = { ...DEFAULT_SETTINGS, theme: "dark" as const };
    await act(async () => {
      await result.current.save(next);
    });

    expect(saveSettings).toHaveBeenCalledWith("user-123", next);
    expect(result.current.settings).toEqual(next);
  });
});
