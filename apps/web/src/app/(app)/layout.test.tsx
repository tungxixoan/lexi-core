import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import AppGroupLayout from "./layout";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettings } from "@/lib/useSettings";
import { usePathname } from "next/navigation";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("next/navigation", () => ({ usePathname: vi.fn(() => "/vocab-bank") }));
vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/useSettings", () => ({ useSettings: vi.fn() }));

describe("AppGroupLayout", () => {
  it("wraps children in SettingsProvider and AppShell", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppGroupLayout>
        <p>page content</p>
      </AppGroupLayout>
    );

    expect(screen.getByText("LexiCore")).toBeInTheDocument();
    expect(screen.getByText("page content")).toBeInTheDocument();
  });
});
