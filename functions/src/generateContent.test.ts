import { describe, expect, it, vi } from "vitest";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { generateContentHandler } from "./generateContent";
import { callGemini } from "./providers/gemini";
import { callGroq, callOpenRouter } from "./providers/openAiCompatible";

vi.mock("./providers/gemini", () => ({ callGemini: vi.fn() }));
vi.mock("./providers/openAiCompatible", () => ({
  callGroq: vi.fn(),
  callOpenRouter: vi.fn(),
}));

function makeRequest(data: unknown, authed = true): CallableRequest<unknown> {
  return {
    auth: authed ? { uid: "user-123" } : undefined,
    data,
  } as CallableRequest<unknown>;
}

describe("generateContentHandler", () => {
  it("throws unauthenticated when there is no auth context", async () => {
    await expect(
      generateContentHandler(
        makeRequest({ provider: "gemini", apiKey: "k", model: "m", prompt: "p" }, false)
      )
    ).rejects.toThrow(HttpsError);
  });

  it("throws invalid-argument for a malformed payload", async () => {
    await expect(
      generateContentHandler(makeRequest({ provider: "gemini" }))
    ).rejects.toThrow(HttpsError);
  });

  it("routes to callGemini for provider 'gemini'", async () => {
    vi.mocked(callGemini).mockResolvedValue({ text: "hello from gemini" });
    const result = await generateContentHandler(
      makeRequest({ provider: "gemini", apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" })
    );
    expect(result).toEqual({ text: "hello from gemini" });
    expect(callGemini).toHaveBeenCalledWith({
      apiKey: "k",
      model: "gemini-2.5-flash",
      prompt: "hi",
    });
  });

  it("routes to callGroq for provider 'groq'", async () => {
    vi.mocked(callGroq).mockResolvedValue({ text: "hello from groq" });
    const result = await generateContentHandler(
      makeRequest({
        provider: "groq",
        apiKey: "k",
        model: "llama-3.3-70b-versatile",
        prompt: "hi",
      })
    );
    expect(result).toEqual({ text: "hello from groq" });
  });

  it("routes to callOpenRouter for provider 'openrouter'", async () => {
    vi.mocked(callOpenRouter).mockResolvedValue({ text: "hello from openrouter" });
    const result = await generateContentHandler(
      makeRequest({
        provider: "openrouter",
        apiKey: "k",
        model: "meta-llama/llama-3.3-70b-instruct",
        prompt: "hi",
      })
    );
    expect(result).toEqual({ text: "hello from openrouter" });
  });

  it("wraps a provider failure in an internal HttpsError", async () => {
    vi.mocked(callGemini).mockRejectedValue(
      new Error("Gemini API error: 429 rate limited")
    );
    await expect(
      generateContentHandler(
        makeRequest({
          provider: "gemini",
          apiKey: "k",
          model: "gemini-2.5-flash",
          prompt: "hi",
        })
      )
    ).rejects.toThrow(HttpsError);
  });

  it("does not leak raw upstream provider error text to the client", async () => {
    vi.mocked(callGemini).mockRejectedValue(
      new Error(
        "Gemini API error: 429 rate limited — user's secret prompt was: ..."
      )
    );
    let caught: unknown;
    try {
      await generateContentHandler(
        makeRequest({
          provider: "gemini",
          apiKey: "k",
          model: "gemini-2.5-flash",
          prompt: "hi",
        })
      );
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(HttpsError);
    const httpsError = caught as HttpsError;
    expect(httpsError.message).toBe("AI provider call failed. Please try again.");
    expect(httpsError.message).not.toContain("secret prompt");
    expect(httpsError.message).not.toContain("429");
  });
});
