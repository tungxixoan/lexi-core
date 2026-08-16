import { doc, getDoc, setDoc } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import { MODEL_PRESETS, type AiProvider } from "./modelPresets";
import type { TargetLanguage } from "./languages";

export interface ProviderSettings {
  model: string;
  apiKeyCiphertext: string | null;
}

export type Theme = "light" | "dark" | "system";
export type FontSize = "small" | "medium" | "large";

export interface UserSettings {
  activeProvider: AiProvider;
  providers: Record<AiProvider, ProviderSettings>;
  theme: Theme;
  fontSize: FontSize;
  targetLanguage: TargetLanguage;
}

export const DEFAULT_SETTINGS: UserSettings = {
  activeProvider: "gemini",
  providers: {
    gemini: { model: MODEL_PRESETS.gemini.defaultModel, apiKeyCiphertext: null },
    groq: { model: MODEL_PRESETS.groq.defaultModel, apiKeyCiphertext: null },
    openrouter: { model: MODEL_PRESETS.openrouter.defaultModel, apiKeyCiphertext: null },
  },
  theme: "system",
  fontSize: "medium",
  targetLanguage: "english",
};

function settingsRef(uid: string) {
  return doc(getFirebaseDb(), "users", uid, "settings", "config");
}

export async function getSettings(uid: string): Promise<UserSettings> {
  const snap = await getDoc(settingsRef(uid));
  if (!snap.exists()) {
    return DEFAULT_SETTINGS;
  }
  const stored = snap.data() as Partial<UserSettings>;
  return {
    ...DEFAULT_SETTINGS,
    ...stored,
    providers: { ...DEFAULT_SETTINGS.providers, ...stored.providers },
  };
}

export async function saveSettings(uid: string, settings: UserSettings): Promise<void> {
  await setDoc(settingsRef(uid), settings);
}
