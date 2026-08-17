import { describe, expect, it, vi } from "vitest";

const callableMock = vi.fn();
vi.mock("firebase/functions", () => ({ httpsCallable: vi.fn(() => callableMock) }));
vi.mock("./firebase", () => ({ getFirebaseFunctions: vi.fn(() => "mock-functions") }));

import { getPronunciationUrl, ttsLanguageCode } from "./pronunciation";

describe("ttsLanguageCode", () => {
  it("maps vietnamese and english to their TTS codes", () => {
    expect(ttsLanguageCode("vietnamese")).toBe("vi");
    expect(ttsLanguageCode("english")).toBe("en");
  });

  it("returns null for languages with no deployed Piper voice", () => {
    expect(ttsLanguageCode("chinese")).toBeNull();
    expect(ttsLanguageCode("korean")).toBeNull();
    expect(ttsLanguageCode("japanese")).toBeNull();
  });
});

describe("getPronunciationUrl", () => {
  it("calls the getPronunciation callable and returns its url", async () => {
    callableMock.mockResolvedValue({ data: { url: "https://example.com/a.wav" } });

    const url = await getPronunciationUrl({ text: "hello", language: "en", tier: "word" });

    expect(url).toBe("https://example.com/a.wav");
    expect(callableMock).toHaveBeenCalledWith({ text: "hello", language: "en", tier: "word" });
  });
});
