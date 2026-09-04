import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { Sidebar } from "./Sidebar";
import { usePathname } from "next/navigation";

vi.mock("next/navigation", () => ({
  usePathname: vi.fn(),
}));

describe("Sidebar", () => {
  it("renders all 8 nav items with the 4 group labels, and marks the current route active", () => {
    vi.mocked(usePathname).mockReturnValue("/vocab-bank");
    render(<Sidebar />);

    expect(screen.getByText("Đọc")).toBeInTheDocument();
    expect(screen.getByText("Quét từ")).toBeInTheDocument();
    expect(screen.getByText("Nghe")).toBeInTheDocument();
    expect(screen.getByText("Khác")).toBeInTheDocument();

    const active = screen.getByRole("link", { name: /Ngân hàng từ vựng/ });
    expect(active).toHaveClass("active");
    expect(active).toHaveAttribute("href", "/vocab-bank");

    const inactive = screen.getByRole("link", { name: /Tổng quan/ });
    expect(inactive).not.toHaveClass("active");
    expect(inactive).toHaveAttribute("href", "/dashboard");
  });

  it("renders exactly 8 nav links (not the mockup's 12 demo entries)", () => {
    vi.mocked(usePathname).mockReturnValue("/vocab-bank");
    render(<Sidebar />);
    expect(screen.getAllByRole("link")).toHaveLength(8);
  });

  it("renders the Word Radar link and marks it active on /word-radar", () => {
    vi.mocked(usePathname).mockReturnValue("/word-radar");
    render(<Sidebar />);

    const radar = screen.getByRole("link", { name: /Quét từ vựng/ });
    expect(radar).toHaveAttribute("href", "/word-radar");
    expect(radar).toHaveClass("active");

    const reading = screen.getByRole("link", { name: /Đọc — tổng quan/ });
    expect(reading).not.toHaveClass("active");
  });

  it("labels the practice nav item 'Ôn tập', not 'Luyện tập'", () => {
    vi.mocked(usePathname).mockReturnValue("/vocab-bank");
    render(<Sidebar />);
    expect(screen.getByRole("link", { name: /Ôn tập/ })).toHaveAttribute("href", "/practice");
    expect(screen.queryByText(/Luyện tập/)).not.toBeInTheDocument();
  });
});
