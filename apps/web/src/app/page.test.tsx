import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import HomePage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";

vi.mock("@/lib/useAuthUser", () => ({
  useAuthUser: vi.fn(),
}));

describe("HomePage", () => {
  it("renders the LexiCore Web heading", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    render(<HomePage />);
    expect(screen.getByRole("heading", { name: "LexiCore Web" })).toBeInTheDocument();
  });
});
