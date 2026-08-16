import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { AccountSection } from "./AccountSection";
import type { User } from "firebase/auth";

describe("AccountSection", () => {
  it("renders the signed-in user's display name and email", () => {
    const user = { displayName: "Tùng Nguyễn", email: "tung@example.com" } as User;
    render(<AccountSection user={user} />);
    expect(screen.getByText("Tùng Nguyễn")).toBeInTheDocument();
    expect(screen.getByText("tung@example.com")).toBeInTheDocument();
  });
});
