import { describe, expect, it } from "vitest";
import { MODEL_PRESETS, PROVIDER_LABELS } from "./modelPresets";

describe("MODEL_PRESETS", () => {
  it("defines the exact Gemini presets and default, matching the Flutter app's AiProvider", () => {
    expect(MODEL_PRESETS.gemini.defaultModel).toBe("gemini-2.5-flash");
    expect(MODEL_PRESETS.gemini.presets).toEqual([
      "gemini-2.5-flash",
      "gemini-2.5-pro",
      "gemini-2.0-flash",
      "gemini-1.5-flash",
    ]);
  });

  it("defines the exact Groq presets and default", () => {
    expect(MODEL_PRESETS.groq.defaultModel).toBe("llama-3.3-70b-versatile");
    expect(MODEL_PRESETS.groq.presets).toEqual([
      "llama-3.3-70b-versatile",
      "llama-3.1-8b-instant",
      "gemma2-9b-it",
    ]);
  });

  it("defines the exact OpenRouter presets and default", () => {
    expect(MODEL_PRESETS.openrouter.defaultModel).toBe("meta-llama/llama-3.3-70b-instruct");
    expect(MODEL_PRESETS.openrouter.presets).toEqual([
      "meta-llama/llama-3.3-70b-instruct",
      "google/gemini-2.5-flash",
      "anthropic/claude-haiku-4-5",
      "mistralai/mixtral-8x7b-instruct",
    ]);
  });
});

describe("PROVIDER_LABELS", () => {
  it("has a Vietnamese-safe display label for every provider", () => {
    expect(PROVIDER_LABELS).toEqual({
      gemini: "Gemini",
      groq: "Groq",
      openrouter: "OpenRouter",
    });
  });
});
