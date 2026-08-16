"use client";

import { useState } from "react";
import { ModelPicker } from "./ModelPicker";
import { encryptApiKey } from "@/lib/encryptApiKey";
import { PROVIDER_LABELS, type AiProvider } from "@/lib/modelPresets";
import type { UserSettings } from "@/lib/settings";

interface AiProviderSectionProps {
  settings: UserSettings;
  onSave: (next: UserSettings) => void | Promise<void>;
}

const PROVIDERS: AiProvider[] = ["gemini", "groq", "openrouter"];

export function AiProviderSection({ settings, onSave }: AiProviderSectionProps) {
  const [keyDraft, setKeyDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const active = settings.activeProvider;
  const activeConfig = settings.providers[active];

  async function handleUpdateKey() {
    const trimmed = keyDraft.trim();
    if (!trimmed) return;
    setSaving(true);
    setError(null);
    try {
      const { ciphertext } = await encryptApiKey({ apiKey: trimmed });
      await onSave({
        ...settings,
        providers: {
          ...settings.providers,
          [active]: { ...activeConfig, apiKeyCiphertext: ciphertext },
        },
      });
      setKeyDraft("");
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="settings-card">
      <h3 className="scr-title">Nhà cung cấp AI &amp; Khoá API</h3>
      <label>
        Nhà cung cấp
        <select
          value={active}
          onChange={(e) =>
            void onSave({ ...settings, activeProvider: e.target.value as AiProvider })
          }
        >
          {PROVIDERS.map((p) => (
            <option key={p} value={p}>
              {PROVIDER_LABELS[p]}
            </option>
          ))}
        </select>
      </label>
      <ModelPicker
        key={active}
        provider={active}
        model={activeConfig.model}
        onChange={(model) =>
          void onSave({
            ...settings,
            providers: { ...settings.providers, [active]: { ...activeConfig, model } },
          })
        }
      />
      <label>
        Khoá API
        <input
          type="password"
          value={keyDraft}
          placeholder={activeConfig.apiKeyCiphertext ? "••••••••" : ""}
          onChange={(e) => setKeyDraft(e.target.value)}
        />
      </label>
      <button className="btn-primary" onClick={() => void handleUpdateKey()} disabled={saving || !keyDraft.trim()}>
        Cập nhật
      </button>
      {error && <p role="alert">{error}</p>}
    </section>
  );
}
