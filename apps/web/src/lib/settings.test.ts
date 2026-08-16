import { describe, expect, it, vi } from "vitest";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { DEFAULT_SETTINGS, getSettings, saveSettings, type UserSettings } from "./settings";

vi.mock("firebase/firestore", () => ({
  doc: vi.fn(() => "mock-doc-ref"),
  getDoc: vi.fn(),
  setDoc: vi.fn(),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

describe("DEFAULT_SETTINGS", () => {
  it("defaults to Gemini active, system theme, medium font size, no keys saved, English target language", () => {
    expect(DEFAULT_SETTINGS.activeProvider).toBe("gemini");
    expect(DEFAULT_SETTINGS.theme).toBe("system");
    expect(DEFAULT_SETTINGS.fontSize).toBe("medium");
    expect(DEFAULT_SETTINGS.providers.gemini.apiKeyCiphertext).toBeNull();
    expect(DEFAULT_SETTINGS.providers.groq.apiKeyCiphertext).toBeNull();
    expect(DEFAULT_SETTINGS.providers.openrouter.apiKeyCiphertext).toBeNull();
    expect(DEFAULT_SETTINGS.targetLanguage).toBe("english");
  });
});

describe("getSettings", () => {
  it("returns DEFAULT_SETTINGS when the doc does not exist", async () => {
    vi.mocked(getDoc).mockResolvedValue({ exists: () => false } as never);
    const result = await getSettings("user-123");
    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "settings", "config");
    expect(result).toEqual(DEFAULT_SETTINGS);
  });

  it("merges the stored doc over the defaults when it exists", async () => {
    const stored: Partial<UserSettings> = {
      activeProvider: "groq",
      theme: "dark",
    };
    vi.mocked(getDoc).mockResolvedValue({
      exists: () => true,
      data: () => stored,
    } as never);

    const result = await getSettings("user-123");

    expect(result.activeProvider).toBe("groq");
    expect(result.theme).toBe("dark");
    expect(result.fontSize).toBe("medium");
    expect(result.providers).toEqual(DEFAULT_SETTINGS.providers);
    // Regression guard: a real pre-existing Firestore doc written before
    // targetLanguage existed has no such key at all, so the merge must fall
    // through to the default rather than leaving it undefined.
    expect(result.targetLanguage).toBe("english");
  });
});

describe("saveSettings", () => {
  it("writes the full settings object to the user's settings/config doc", async () => {
    const settings: UserSettings = {
      ...DEFAULT_SETTINGS,
      activeProvider: "openrouter",
    };
    await saveSettings("user-123", settings);
    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "settings", "config");
    expect(setDoc).toHaveBeenCalledWith("mock-doc-ref", settings);
  });
});
