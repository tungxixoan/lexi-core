import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { Sidebar } from "./Sidebar";
import { usePathname } from "next/navigation";

vi.mock("next/navigation", () => ({
  usePathname: vi.fn(),
}));

describe("Sidebar", () => {
  it("renders all 7 nav items with the 3 group labels, and marks the current route active", () => {
    vi.mocked(usePathname).mockReturnValue("/vocab-bank");
    render(<Sidebar />);

    expect(screen.getByText("Đọc")).toBeInTheDocument();
    expect(screen.getByText("Nghe")).toBeInTheDocument();
    expect(screen.getByText("Khác")).toBeInTheDocument();

    const active = screen.getByRole("link", { name: /Ngân hàng từ vựng/ });
    expect(active).toHaveClass("active");
    expect(active).toHaveAttribute("href", "/vocab-bank");

    const inactive = screen.getByRole("link", { name: /Tổng quan/ });
    expect(inactive).not.toHaveClass("active");
    expect(inactive).toHaveAttribute("href", "/dashboard");
  });

  it("renders exactly 7 nav links (not the mockup's 12 demo entries)", () => {
    vi.mocked(usePathname).mockReturnValue("/vocab-bank");
    render(<Sidebar />);
    expect(screen.getAllByRole("link")).toHaveLength(7);
  });
});
