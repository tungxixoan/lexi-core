export type AiProvider = "gemini" | "groq" | "openrouter";

export interface ProviderModelInfo {
  defaultModel: string;
  presets: string[];
}

// Mirrors lib/features/dictionary/domain/entities/ai_provider.dart's
// AiProviderX.defaultModel/modelPresets — kept in sync manually (no
// shared-types package between the Flutter and web apps).
export const MODEL_PRESETS: Record<AiProvider, ProviderModelInfo> = {
  gemini: {
    defaultModel: "gemini-2.5-flash",
    presets: ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash", "gemini-1.5-flash"],
  },
  groq: {
    defaultModel: "llama-3.3-70b-versatile",
    presets: [
      "llama-3.3-70b-versatile",
      "llama-3.1-8b-instant",
      "gemma2-9b-it",
    ],
  },
  openrouter: {
    defaultModel: "meta-llama/llama-3.3-70b-instruct",
    presets: [
      "meta-llama/llama-3.3-70b-instruct",
      "google/gemini-2.5-flash",
      "anthropic/claude-haiku-4-5",
      "mistralai/mixtral-8x7b-instruct",
    ],
  },
};

export const PROVIDER_LABELS: Record<AiProvider, string> = {
  gemini: "Gemini",
  groq: "Groq",
  openrouter: "OpenRouter",
};
