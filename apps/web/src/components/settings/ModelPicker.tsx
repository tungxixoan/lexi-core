"use client";

import { useState } from "react";
import { MODEL_PRESETS, type AiProvider } from "@/lib/modelPresets";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";

const CUSTOM_VALUE = "__custom__";

interface ModelPickerProps {
  provider: AiProvider;
  model: string;
  onChange: (model: string) => void;
}

export function ModelPicker({ provider, model, onChange }: ModelPickerProps) {
  const { presets } = MODEL_PRESETS[provider];
  const modelIsPreset = presets.includes(model);
  // `customMode` tracks the user's dropdown choice locally: selecting
  // "Khác..." must reveal the free-text input immediately, before onChange
  // has fired and before the `model` prop has changed — isCustom can't be
  // derived from `model` alone, or the input would never appear (selecting
  // "Khác..." wouldn't change `model`, so a props-only isCustom would stay
  // false and the input required to fix that would never render).
  const [customMode, setCustomMode] = useState(!modelIsPreset);
  const [customDraft, setCustomDraft] = useState(model);

  const showCustomInput = customMode || !modelIsPreset;

  const options: SimpleDropdownOption<string>[] = [
    ...presets.map((m) => ({ value: m, label: m })),
    { value: CUSTOM_VALUE, label: "Khác..." },
  ];

  return (
    <div>
      <div className="settings-field">
        <span>Model</span>
        <SimpleDropdown
          ariaLabel="Chọn model"
          triggerLabel={showCustomInput ? "Khác..." : model}
          options={options}
          value={showCustomInput ? CUSTOM_VALUE : model}
          onChange={(value) => {
            if (value === CUSTOM_VALUE) {
              setCustomMode(true);
              setCustomDraft(modelIsPreset ? "" : model);
            } else {
              setCustomMode(false);
              onChange(value);
            }
          }}
          active={false}
        />
      </div>
      {showCustomInput && (
        <input
          aria-label="Tên model tuỳ chỉnh"
          value={customDraft}
          onChange={(e) => setCustomDraft(e.target.value)}
          onBlur={() => {
            if (customDraft.trim()) onChange(customDraft.trim());
          }}
        />
      )}
    </div>
  );
}
