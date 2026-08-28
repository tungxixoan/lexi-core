import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import HomePage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({
  useAuthUser: vi.fn(),
}));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));

describe("HomePage", () => {
  it("renders the LexiCore Web heading", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    } as never);
    render(<HomePage />);
    expect(screen.getByRole("heading", { name: "LexiCore Web" })).toBeInTheDocument();
  });
});
