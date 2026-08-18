"use client";

import { useState } from "react";
import { LANGUAGE_LABELS, type TargetLanguage } from "@/lib/languages";
import type { UserSettings } from "@/lib/settings";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";

interface LanguageSectionProps {
  settings: UserSettings;
  onSave: (next: UserSettings) => void | Promise<void>;
}

const LANGUAGES: TargetLanguage[] = ["vietnamese", "english", "chinese", "korean", "japanese"];
const LANGUAGE_OPTIONS: SimpleDropdownOption<TargetLanguage>[] = LANGUAGES.map((lang) => ({
  value: lang,
  label: LANGUAGE_LABELS[lang],
}));

export function LanguageSection({ settings, onSave }: LanguageSectionProps) {
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
      <h3 className="scr-title">Ngôn ngữ mục tiêu</h3>
      <div className="settings-field">
        <span>Ngôn ngữ đang học</span>
        <SimpleDropdown
          ariaLabel="Ngôn ngữ đang học"
          triggerLabel={LANGUAGE_LABELS[settings.targetLanguage]}
          options={LANGUAGE_OPTIONS}
          value={settings.targetLanguage}
          onChange={(lang) => void handleSave({ ...settings, targetLanguage: lang })}
          active={false}
        />
      </div>
      {error && <p role="alert">{error}</p>}
    </section>
  );
}
