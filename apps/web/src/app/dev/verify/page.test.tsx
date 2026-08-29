import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import HomePage from "./page";
import DevLayout from "../layout";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettings } from "@/lib/useSettings";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({
  useAuthUser: vi.fn(),
}));
vi.mock("@/lib/useSettings", () => ({ useSettings: vi.fn() }));

describe("HomePage", () => {
  it("renders the LexiCore Web heading inside the real dev layout/provider chain", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    vi.mocked(useSettings).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    });
    render(
      <DevLayout>
        <HomePage />
      </DevLayout>
    );
    expect(screen.getByRole("heading", { name: "LexiCore Web" })).toBeInTheDocument();
  });
});
