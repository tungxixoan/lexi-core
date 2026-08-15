import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { AppShell } from "./AppShell";
import { usePathname } from "next/navigation";

vi.mock("next/navigation", () => ({
  usePathname: vi.fn(() => "/vocab-bank"),
}));

describe("AppShell", () => {
  it("renders the sidebar brand and the children inside the main content area", () => {
    render(
      <AppShell>
        <p>Screen content</p>
      </AppShell>
    );
    expect(screen.getByText("LexiCore")).toBeInTheDocument();
    const main = screen.getByText("Screen content").closest("main");
    expect(main).toHaveClass("main");
  });
});
