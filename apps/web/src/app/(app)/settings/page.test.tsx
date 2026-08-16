import { describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import SettingsPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

describe("SettingsPage", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: null,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(<SettingsPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("renders every section once settings have loaded", async () => {
    const user = { uid: "u1", displayName: "Tùng", email: "tung@example.com" };
    vi.mocked(useAuthUser).mockReturnValue({ user, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(<SettingsPage />);

    expect(await screen.findByText("Tài khoản")).toBeInTheDocument();
    expect(screen.getByText("Ngôn ngữ mục tiêu")).toBeInTheDocument();
    expect(screen.getByText("Nhà cung cấp AI & Khoá API")).toBeInTheDocument();
    expect(screen.getByText("Giao diện")).toBeInTheDocument();
    expect(screen.getByText("Vùng nguy hiểm")).toBeInTheDocument();
  });

  it("shows a loading state while settings are loading", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: null,
      loading: true,
      error: null,
      save: vi.fn(),
    });

    render(<SettingsPage />);
    expect(screen.getByText("Đang tải cài đặt…")).toBeInTheDocument();
  });

  it("shows an alert when settings fail to load", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: null,
      loading: false,
      error: "offline",
      save: vi.fn(),
    });

    render(<SettingsPage />);
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("offline"));
  });
});
