"use client";

import { useState } from "react";
import type { FontSize, Theme, UserSettings } from "@/lib/settings";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";

interface AppearanceSectionProps {
  settings: UserSettings;
  onSave: (next: UserSettings) => void | Promise<void>;
}

const THEMES: Theme[] = ["light", "dark", "system"];
const THEME_LABELS: Record<Theme, string> = {
  light: "Sáng",
  dark: "Tối",
  system: "Theo hệ thống",
};
const THEME_OPTIONS: SimpleDropdownOption<Theme>[] = THEMES.map((t) => ({
  value: t,
  label: THEME_LABELS[t],
}));

const FONT_SIZES: FontSize[] = ["small", "medium", "large"];
const FONT_SIZE_LABELS: Record<FontSize, string> = {
  small: "Nhỏ",
  medium: "Vừa",
  large: "Lớn",
};
const FONT_SIZE_OPTIONS: SimpleDropdownOption<FontSize>[] = FONT_SIZES.map((f) => ({
  value: f,
  label: FONT_SIZE_LABELS[f],
}));

export function AppearanceSection({ settings, onSave }: AppearanceSectionProps) {
  const [error, setError] = useState<string | null>(null);

  async function handleSave(next: UserSettings) {
    setError(null);
    try {
      await onSave(next);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }

  return (
    <section className="settings-card">
      <h3 className="scr-title">Giao diện</h3>
      <div className="settings-field">
        <span>Chủ đề</span>
        <SimpleDropdown
          ariaLabel="Chọn chủ đề giao diện"
          triggerLabel={THEME_LABELS[settings.theme]}
          options={THEME_OPTIONS}
          value={settings.theme}
          onChange={(theme) => void handleSave({ ...settings, theme })}
          active={false}
        />
      </div>
      <div className="settings-field">
        <span>Cỡ chữ</span>
        <SimpleDropdown
          ariaLabel="Chọn cỡ chữ"
          triggerLabel={FONT_SIZE_LABELS[settings.fontSize]}
          options={FONT_SIZE_OPTIONS}
          value={settings.fontSize}
          onChange={(fontSize) => void handleSave({ ...settings, fontSize })}
          active={false}
        />
      </div>
      {error && <p role="alert">{error}</p>}
    </section>
  );
}
