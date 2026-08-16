import { afterEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { AppShell } from "./AppShell";
import { usePathname } from "next/navigation";
import { useSettingsContext } from "@/lib/SettingsContext";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("next/navigation", () => ({
  usePathname: vi.fn(() => "/vocab-bank"),
}));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));

afterEach(() => {
  document.documentElement.removeAttribute("data-theme");
});

describe("AppShell", () => {
  it("renders the sidebar brand and the children inside the main content area", () => {
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>Screen content</p>
      </AppShell>
    );
    expect(screen.getByText("LexiCore")).toBeInTheDocument();
    const main = screen.getByText("Screen content").closest("main");
    expect(main).toHaveClass("main");
  });

  it("sets data-theme='dark' on <html> when the loaded settings say theme is dark", async () => {
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: { ...DEFAULT_SETTINGS, theme: "dark" },
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>content</p>
      </AppShell>
    );

    await waitFor(() =>
      expect(document.documentElement.getAttribute("data-theme")).toBe("dark")
    );
  });

  it("removes data-theme from <html> when theme is 'system'", async () => {
    document.documentElement.setAttribute("data-theme", "dark");
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: { ...DEFAULT_SETTINGS, theme: "system" },
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>content</p>
      </AppShell>
    );

    await waitFor(() =>
      expect(document.documentElement.hasAttribute("data-theme")).toBe(false)
    );
  });

  it("applies the fs-large class to .app-frame when font size is large", () => {
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: { ...DEFAULT_SETTINGS, fontSize: "large" },
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>content</p>
      </AppShell>
    );

    expect(screen.getByText("content").closest(".app-frame")).toHaveClass("fs-large");
  });

  it("applies no font-size class for the medium (default) size", () => {
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>content</p>
      </AppShell>
    );

    const frame = screen.getByText("content").closest(".app-frame");
    expect(frame).not.toHaveClass("fs-small");
    expect(frame).not.toHaveClass("fs-large");
  });
});
