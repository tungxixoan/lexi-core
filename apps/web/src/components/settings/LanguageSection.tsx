"use client";

import { useState } from "react";
import { LANGUAGE_LABELS, type TargetLanguage } from "@/lib/languages";
import type { UserSettings } from "@/lib/settings";

interface LanguageSectionProps {
  settings: UserSettings;
  onSave: (next: UserSettings) => void | Promise<void>;
}

const LANGUAGES: TargetLanguage[] = ["vietnamese", "english", "chinese", "korean", "japanese"];

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
      <label>
        Ngôn ngữ đang học
        <select
          value={settings.targetLanguage}
          onChange={(e) =>
            void handleSave({ ...settings, targetLanguage: e.target.value as TargetLanguage })
          }
        >
          {LANGUAGES.map((lang) => (
            <option key={lang} value={lang}>
              {LANGUAGE_LABELS[lang]}
            </option>
          ))}
        </select>
      </label>
      {error && <p role="alert">{error}</p>}
    </section>
  );
}
