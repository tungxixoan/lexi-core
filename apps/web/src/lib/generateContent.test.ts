import { describe, expect, it, vi } from "vitest";
import { httpsCallable } from "firebase/functions";
import { generateContent } from "./generateContent";

vi.mock("firebase/functions", () => ({
  httpsCallable: vi.fn(),
  getFunctions: vi.fn(),
}));
vi.mock("./firebase", () => ({
  getFirebaseFunctions: vi.fn(() => "mock-functions"),
}));

describe("generateContent", () => {
  it("calls the generateContent callable and returns its data", async () => {
    const mockCallable = vi.fn().mockResolvedValue({ data: { text: "hello" } });
    vi.mocked(httpsCallable).mockReturnValue(mockCallable as never);

    const result = await generateContent({
      provider: "gemini",
      apiKey: "k",
      model: "gemini-2.5-flash",
      prompt: "hi",
    });

    expect(result).toEqual({ text: "hello" });
    expect(httpsCallable).toHaveBeenCalledWith("mock-functions", "generateContent");
    expect(mockCallable).toHaveBeenCalledWith({
      provider: "gemini",
      apiKey: "k",
      model: "gemini-2.5-flash",
      prompt: "hi",
    });
  });
});
