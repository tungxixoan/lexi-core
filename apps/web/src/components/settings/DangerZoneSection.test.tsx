import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { DangerZoneSection } from "./DangerZoneSection";
import { signOutOfFirebase } from "@/lib/auth";

vi.mock("@/lib/auth", () => ({ signOutOfFirebase: vi.fn() }));

describe("DangerZoneSection", () => {
  it("calls signOutOfFirebase when Đăng xuất is clicked", () => {
    render(<DangerZoneSection />);
    fireEvent.click(screen.getByRole("button", { name: "Đăng xuất" }));
    expect(signOutOfFirebase).toHaveBeenCalledOnce();
  });
});
