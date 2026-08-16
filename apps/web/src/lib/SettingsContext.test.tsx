import { describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { SettingsProvider, useSettingsContext } from "./SettingsContext";
import { useAuthUser } from "./useAuthUser";
import { useSettings } from "./useSettings";
import { DEFAULT_SETTINGS } from "./settings";

vi.mock("./useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("./useSettings", () => ({ useSettings: vi.fn() }));

function Consumer() {
  const { settings } = useSettingsContext();
  return <p>{settings?.theme}</p>;
}

describe("SettingsProvider / useSettingsContext", () => {
  it("provides the single useSettings(uid) instance to all consumers", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: { ...DEFAULT_SETTINGS, theme: "dark" },
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <SettingsProvider>
        <Consumer />
      </SettingsProvider>
    );

    expect(screen.getByText("dark")).toBeInTheDocument();
    expect(useSettings).toHaveBeenCalledWith("u1");
    expect(useSettings).toHaveBeenCalledTimes(1);
  });

  it("throws when useSettingsContext is called outside a SettingsProvider", () => {
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});
    expect(() => render(<Consumer />)).toThrow(
      "useSettingsContext must be used within a SettingsProvider"
    );
    spy.mockRestore();
  });

  it("multiple consumers share the same settings/save reference (single fetch, single write path)", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    const save = vi.fn();
    vi.mocked(useSettings).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save,
    });

    function ConsumerB() {
      const { save: saveB } = useSettingsContext();
      return (
        <button onClick={() => void saveB({ ...DEFAULT_SETTINGS, theme: "dark" })}>go</button>
      );
    }

    render(
      <SettingsProvider>
        <Consumer />
        <ConsumerB />
      </SettingsProvider>
    );

    screen.getByText("go").click();
    await waitFor(() => expect(save).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, theme: "dark" }));
  });
});
