import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import ReadingHubPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

describe("ReadingHubPage", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<ReadingHubPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the Đọc & gõ card linking to /reading/bilingual when signed in", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    render(<ReadingHubPage />);
    const link = screen.getByRole("link", { name: /Đọc & gõ/ });
    expect(link).toHaveAttribute("href", "/reading/bilingual");
  });

  it("shows the Part 5 card linking to /reading/part5 when signed in", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    render(<ReadingHubPage />);
    const link = screen.getByRole("link", { name: /Part 5/ });
    expect(link).toHaveAttribute("href", "/reading/part5");
  });
});
