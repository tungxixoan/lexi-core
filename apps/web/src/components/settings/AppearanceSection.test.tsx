import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { AppearanceSection } from "./AppearanceSection";
import { DEFAULT_SETTINGS } from "@/lib/settings";

describe("AppearanceSection", () => {
  it("renders the current theme and font size", () => {
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={vi.fn()} />);
    expect(screen.getByLabelText("Chủ đề")).toHaveValue("system");
    expect(screen.getByLabelText("Cỡ chữ")).toHaveValue("medium");
  });

  it("calls onSave with the new theme when changed", () => {
    const onSave = vi.fn();
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.change(screen.getByLabelText("Chủ đề"), { target: { value: "dark" } });
    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, theme: "dark" });
  });

  it("calls onSave with the new font size when changed", () => {
    const onSave = vi.fn();
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.change(screen.getByLabelText("Cỡ chữ"), { target: { value: "large" } });
    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, fontSize: "large" });
  });
});
