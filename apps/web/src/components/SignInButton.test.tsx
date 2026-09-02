import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { SignInButton } from "./SignInButton";
import { signInWithGoogle, signOutOfFirebase } from "@/lib/auth";
import { useAuthUser } from "@/lib/useAuthUser";

vi.mock("@/lib/auth", () => ({
  signInWithGoogle: vi.fn(),
  signOutOfFirebase: vi.fn(),
}));

vi.mock("@/lib/useAuthUser", () => ({
  useAuthUser: vi.fn(),
}));

describe("SignInButton", () => {
  it("shows a loading state while auth is resolving", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: true });
    render(<SignInButton />);
    expect(screen.getByRole("button", { name: "Đang tải…" })).toBeDisabled();
  });

  it("shows a sign-in button and calls signInWithGoogle when signed out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    render(<SignInButton />);
    const btn = screen.getByRole("button", { name: "Đăng nhập với Google" });
    expect(btn).toHaveClass("btn-google");
    expect(btn.querySelector("svg")).not.toBeNull();
    fireEvent.click(btn);
    expect(signInWithGoogle).toHaveBeenCalledOnce();
  });

  it("shows the user's name and calls signOutOfFirebase when signed in", () => {
    vi.mocked(useAuthUser).mockReturnValue({
      user: { displayName: "Nguyễn Anh", email: "anh@example.com" } as never,
      loading: false,
    });
    render(<SignInButton />);
    fireEvent.click(
      screen.getByRole("button", { name: "Đăng xuất (Nguyễn Anh)" })
    );
    expect(signOutOfFirebase).toHaveBeenCalledOnce();
  });
});
