import { describe, expect, it, vi } from "vitest";
import { redirect } from "next/navigation";
import HomePage from "./page";

vi.mock("next/navigation", () => ({
  redirect: vi.fn(),
}));

describe("HomePage (/)", () => {
  it("redirects to /vocab-bank", () => {
    HomePage();
    expect(redirect).toHaveBeenCalledWith("/vocab-bank");
  });
});
