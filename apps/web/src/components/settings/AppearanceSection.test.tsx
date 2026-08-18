import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { AppearanceSection } from "./AppearanceSection";
import { DEFAULT_SETTINGS } from "@/lib/settings";

describe("AppearanceSection", () => {
  it("renders the current theme and font size", () => {
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={vi.fn()} />);
    expect(screen.getByRole("button", { name: "Theo hệ thống ▾" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Vừa ▾" })).toBeInTheDocument();
  });

  it("calls onSave with the new theme when a different one is picked", () => {
    const onSave = vi.fn();
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "Theo hệ thống ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "Tối" }));
    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, theme: "dark" });
  });

  it("calls onSave with the new font size when a different one is picked", () => {
    const onSave = vi.fn();
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "Vừa ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "Lớn" }));
    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, fontSize: "large" });
  });

  it("shows an alert when saving the theme fails", async () => {
    const onSave = vi.fn().mockRejectedValue(new Error("offline"));
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "Theo hệ thống ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "Tối" }));
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("offline"));
  });

  it("shows an alert when saving the font size fails", async () => {
    const onSave = vi.fn().mockRejectedValue(new Error("offline"));
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "Vừa ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "Lớn" }));
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("offline"));
  });
});
