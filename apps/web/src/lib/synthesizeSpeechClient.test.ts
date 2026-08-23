import { describe, expect, it, vi } from "vitest";
import { httpsCallable } from "firebase/functions";
import { synthesizeSpeech, toAudioDataUrl } from "./synthesizeSpeechClient";

vi.mock("firebase/functions", () => ({
  httpsCallable: vi.fn(),
}));
vi.mock("./firebase", () => ({
  getFirebaseFunctions: vi.fn(() => "mock-functions"),
}));

describe("synthesizeSpeech", () => {
  it("calls the synthesizeSpeech callable with the given text and language, and returns its data", async () => {
    const callable = vi.fn().mockResolvedValue({ data: { audioBase64: "AAAA" } });
    vi.mocked(httpsCallable).mockReturnValue(callable as never);

    const result = await synthesizeSpeech({ text: "Hello world.", language: "en" });

    expect(httpsCallable).toHaveBeenCalledWith("mock-functions", "synthesizeSpeech");
    expect(callable).toHaveBeenCalledWith({ text: "Hello world.", language: "en" });
    expect(result).toEqual({ audioBase64: "AAAA" });
  });
});

describe("toAudioDataUrl", () => {
  it("wraps a base64 string as a playable audio/wav data URL", () => {
    expect(toAudioDataUrl("AAAA")).toBe("data:audio/wav;base64,AAAA");
  });
});
