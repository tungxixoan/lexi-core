"use client";

import { useState } from "react";

export interface SimpleDropdownOption<T extends string> {
  value: T;
  label: string;
}

interface SimpleDropdownProps<T extends string> {
  triggerLabel: string;
  ariaLabel: string;
  options: SimpleDropdownOption<T>[];
  value: T;
  onChange: (value: T) => void;
  active: boolean;
}

export function SimpleDropdown<T extends string>({
  triggerLabel,
  ariaLabel,
  options,
  value,
  onChange,
  active,
}: SimpleDropdownProps<T>) {
  const [open, setOpen] = useState(false);

  return (
    <div className="vb-topic-popover-wrap">
      <button type="button" className={`vb-chip${active ? " active" : ""}`} onClick={() => setOpen((o) => !o)}>
        {triggerLabel} ▾
      </button>
      {open && (
        <div className="vb-topic-popover" role="listbox" aria-label={ariaLabel}>
          <div className="vb-topic-popover-opts">
            {options.map((opt) => (
              <button
                type="button"
                key={opt.value}
                role="option"
                aria-selected={opt.value === value}
                className={`vb-chip${opt.value === value ? " active" : ""}`}
                onClick={() => {
                  onChange(opt.value);
                  setOpen(false);
                }}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
