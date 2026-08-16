"use client";

import type { FontSize, Theme, UserSettings } from "@/lib/settings";

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

const FONT_SIZES: FontSize[] = ["small", "medium", "large"];
const FONT_SIZE_LABELS: Record<FontSize, string> = {
  small: "Nhỏ",
  medium: "Vừa",
  large: "Lớn",
};

export function AppearanceSection({ settings, onSave }: AppearanceSectionProps) {
  return (
    <section>
      <h3 className="scr-title">Giao diện</h3>
      <label>
        Chủ đề
        <select
          value={settings.theme}
          onChange={(e) => void onSave({ ...settings, theme: e.target.value as Theme })}
        >
          {THEMES.map((t) => (
            <option key={t} value={t}>
              {THEME_LABELS[t]}
            </option>
          ))}
        </select>
      </label>
      <label>
        Cỡ chữ
        <select
          value={settings.fontSize}
          onChange={(e) => void onSave({ ...settings, fontSize: e.target.value as FontSize })}
        >
          {FONT_SIZES.map((f) => (
            <option key={f} value={f}>
              {FONT_SIZE_LABELS[f]}
            </option>
          ))}
        </select>
      </label>
    </section>
  );
}
