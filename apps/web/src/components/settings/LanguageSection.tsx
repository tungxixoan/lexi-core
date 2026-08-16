"use client";

import { LANGUAGE_LABELS, type TargetLanguage } from "@/lib/languages";
import type { UserSettings } from "@/lib/settings";

interface LanguageSectionProps {
  settings: UserSettings;
  onSave: (next: UserSettings) => void | Promise<void>;
}

const LANGUAGES: TargetLanguage[] = ["vietnamese", "english", "chinese", "korean", "japanese"];

export function LanguageSection({ settings, onSave }: LanguageSectionProps) {
  return (
    <section className="settings-card">
      <h3 className="scr-title">Ngôn ngữ mục tiêu</h3>
      <label>
        Ngôn ngữ đang học
        <select
          value={settings.targetLanguage}
          onChange={(e) =>
            void onSave({ ...settings, targetLanguage: e.target.value as TargetLanguage })
          }
        >
          {LANGUAGES.map((lang) => (
            <option key={lang} value={lang}>
              {LANGUAGE_LABELS[lang]}
            </option>
          ))}
        </select>
      </label>
    </section>
  );
}
