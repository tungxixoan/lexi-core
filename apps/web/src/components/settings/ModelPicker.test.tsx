import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { ModelPicker } from "./ModelPicker";

describe("ModelPicker", () => {
  it("renders all presets for the given provider plus a 'Khác...' option", () => {
    render(<ModelPicker provider="gemini" model="gemini-2.5-flash" onChange={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", { name: "gemini-2.5-flash ▾" }));
    expect(screen.getByRole("option", { name: "gemini-2.5-pro" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "gemini-1.5-flash" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "Khác..." })).toBeInTheDocument();
  });

  it("calls onChange when a different preset is selected", () => {
    const onChange = vi.fn();
    render(<ModelPicker provider="gemini" model="gemini-2.5-flash" onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", { name: "gemini-2.5-flash ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "gemini-2.5-pro" }));
    expect(onChange).toHaveBeenCalledWith("gemini-2.5-pro");
  });

  it("shows a custom text input immediately when the current model is not a preset", () => {
    render(<ModelPicker provider="gemini" model="gemini-3.0-experimental" onChange={vi.fn()} />);
    expect(screen.getByLabelText("Tên model tuỳ chỉnh")).toHaveValue("gemini-3.0-experimental");
    expect(screen.getByRole("button", { name: "Khác... ▾" })).toBeInTheDocument();
  });

  it("reveals the custom input after selecting 'Khác...', and calls onChange on blur with the typed value", () => {
    const onChange = vi.fn();
    render(<ModelPicker provider="groq" model="llama-3.3-70b-versatile" onChange={onChange} />);

    fireEvent.click(screen.getByRole("button", { name: "llama-3.3-70b-versatile ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "Khác..." }));

    const input = screen.getByLabelText("Tên model tuỳ chỉnh");
    fireEvent.change(input, { target: { value: "llama-4-new-model" } });
    fireEvent.blur(input);

    expect(onChange).toHaveBeenCalledWith("llama-4-new-model");
  });

  it("does not call onChange on blur when the custom input is empty", () => {
    const onChange = vi.fn();
    render(<ModelPicker provider="groq" model="not-a-preset" onChange={onChange} />);
    const input = screen.getByLabelText("Tên model tuỳ chỉnh");
    fireEvent.change(input, { target: { value: "  " } });
    fireEvent.blur(input);
    expect(onChange).not.toHaveBeenCalled();
  });
});
