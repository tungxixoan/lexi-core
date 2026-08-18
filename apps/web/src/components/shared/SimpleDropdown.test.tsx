import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { SimpleDropdown } from "./SimpleDropdown";

const OPTIONS = [
  { value: "", label: "Mọi trình độ" },
  { value: "a1", label: "Tối đa A1" },
  { value: "b1", label: "Tối đa B1" },
];

describe("SimpleDropdown", () => {
  it("shows the trigger closed by default", () => {
    render(
      <SimpleDropdown
        triggerLabel="Mọi trình độ"
        ariaLabel="Chọn trình độ"
        options={OPTIONS}
        value=""
        onChange={vi.fn()}
        active={false}
      />
    );
    expect(screen.getByRole("button", { name: "Mọi trình độ ▾" })).toBeInTheDocument();
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
  });

  it("opens on click, lists every option, and marks the current value selected", () => {
    render(
      <SimpleDropdown
        triggerLabel="Tối đa A1"
        ariaLabel="Chọn trình độ"
        options={OPTIONS}
        value="a1"
        onChange={vi.fn()}
        active
      />
    );
    fireEvent.click(screen.getByRole("button", { name: "Tối đa A1 ▾" }));

    expect(screen.getByRole("listbox", { name: "Chọn trình độ" })).toBeInTheDocument();
    const options = screen.getAllByRole("option");
    expect(options).toHaveLength(3);
    expect(screen.getByRole("option", { name: "Tối đa A1" })).toHaveAttribute("aria-selected", "true");
    expect(screen.getByRole("option", { name: "Mọi trình độ" })).toHaveAttribute("aria-selected", "false");
  });

  it("calls onChange and closes the panel when an option is clicked", () => {
    const onChange = vi.fn();
    render(
      <SimpleDropdown
        triggerLabel="Mọi trình độ"
        ariaLabel="Chọn trình độ"
        options={OPTIONS}
        value=""
        onChange={onChange}
        active={false}
      />
    );
    fireEvent.click(screen.getByRole("button", { name: "Mọi trình độ ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "Tối đa B1" }));

    expect(onChange).toHaveBeenCalledWith("b1");
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
  });

  it("highlights the trigger chip when active", () => {
    render(
      <SimpleDropdown
        triggerLabel="Tối đa A1"
        ariaLabel="Chọn trình độ"
        options={OPTIONS}
        value="a1"
        onChange={vi.fn()}
        active
      />
    );
    expect(screen.getByRole("button", { name: "Tối đa A1 ▾" })).toHaveClass("active");
  });
});
