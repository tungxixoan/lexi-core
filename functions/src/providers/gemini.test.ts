import { describe, expect, it, vi } from "vitest";
import { callGemini } from "./gemini";
import { ProviderApiError } from "./types";

describe("callGemini", () => {
  it("sends the API key as a header, never a query string, and returns the text", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: "Xin chào" }] } }],
      }),
    });

    const result = await callGemini(
      { apiKey: "secret-key", model: "gemini-2.5-flash", prompt: "Say hi in Vietnamese" },
      mockFetch as unknown as typeof fetch
    );

    expect(result).toEqual({ text: "Xin chào" });
    const [url, options] = mockFetch.mock.calls[0];
    expect(url).toBe(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    );
    expect(url).not.toContain("secret-key");
    expect((options.headers as Record<string, string>)["x-goog-api-key"]).toBe(
      "secret-key"
    );
  });

  it("throws when the response has no candidates", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true, json: async () => ({}) });
    await expect(
      callGemini(
        { apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" },
        mockFetch as unknown as typeof fetch
      )
    ).rejects.toThrow("Gemini API returned no text.");
  });

  it("throws with the status and body when the response is not ok", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 429,
      text: async () => "rate limited",
    });
    await expect(
      callGemini(
        { apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" },
        mockFetch as unknown as typeof fetch
      )
    ).rejects.toThrow("Gemini API error: 429 rate limited");
  });

  it("throws a ProviderApiError carrying the upstream status when the response is not ok", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => "API key not valid",
    });
    let caught: unknown;
    try {
      await callGemini(
        { apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" },
        mockFetch as unknown as typeof fetch
      );
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(ProviderApiError);
    expect((caught as ProviderApiError).status).toBe(401);
  });
});
