import { describe, expect, it, vi } from "vitest";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { generateContentHandler, generateContent } from "./generateContent";
import { callGemini } from "./providers/gemini";
import { callGroq, callOpenRouter } from "./providers/openAiCompatible";
import { ProviderApiError } from "./providers/types";

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

  it("maps a 401 ProviderApiError to permission-denied without leaking the response body", async () => {
    vi.mocked(callGemini).mockRejectedValue(
      new ProviderApiError(
        "Gemini API error: 401 { \"error\": { \"message\": \"API key not valid. Please pass a valid API key.\" } }",
        401
      )
    );
    let caught: unknown;
    try {
      await generateContentHandler(
        makeRequest({ provider: "gemini", apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" })
      );
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(HttpsError);
    const httpsError = caught as HttpsError;
    expect(httpsError.code).toBe("permission-denied");
    expect(httpsError.message).toBe(
      "Provider rejected the API key. Check it's correct and active."
    );
    expect(httpsError.message).not.toContain("API key not valid");
    expect(httpsError.message).not.toContain("401");
  });

  it("maps a 403 ProviderApiError to permission-denied", async () => {
    vi.mocked(callGemini).mockRejectedValue(
      new ProviderApiError("Gemini API error: 403 forbidden", 403)
    );
    await expect(
      generateContentHandler(
        makeRequest({ provider: "gemini", apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("maps a 429 ProviderApiError to resource-exhausted without leaking the response body", async () => {
    vi.mocked(callGroq).mockRejectedValue(
      new ProviderApiError(
        "https://api.groq.com/openai/v1 API error: 429 rate limit exceeded, retry after 5s",
        429
      )
    );
    let caught: unknown;
    try {
      await generateContentHandler(
        makeRequest({
          provider: "groq",
          apiKey: "k",
          model: "llama-3.3-70b-versatile",
          prompt: "hi",
        })
      );
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(HttpsError);
    const httpsError = caught as HttpsError;
    expect(httpsError.code).toBe("resource-exhausted");
    expect(httpsError.message).toBe(
      "Provider rate limit or quota exceeded. Try again shortly."
    );
    expect(httpsError.message).not.toContain("retry after 5s");
  });

  it("maps a 500 ProviderApiError to unavailable without leaking the response body", async () => {
    vi.mocked(callOpenRouter).mockRejectedValue(
      new ProviderApiError(
        "https://openrouter.ai/api/v1 API error: 500 internal server error, high demand",
        500
      )
    );
    let caught: unknown;
    try {
      await generateContentHandler(
        makeRequest({
          provider: "openrouter",
          apiKey: "k",
          model: "meta-llama/llama-3.3-70b-instruct",
          prompt: "hi",
        })
      );
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(HttpsError);
    const httpsError = caught as HttpsError;
    expect(httpsError.code).toBe("unavailable");
    expect(httpsError.message).toBe(
      "Provider is temporarily unavailable. Try again in a moment."
    );
    expect(httpsError.message).not.toContain("high demand");
  });

  it("still falls back to the generic internal error for a plain Error (e.g. 'no text in response')", async () => {
    vi.mocked(callGemini).mockRejectedValue(new Error("Gemini API returned no text."));
    await expect(
      generateContentHandler(
        makeRequest({ provider: "gemini", apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" })
      )
    ).rejects.toMatchObject({
      code: "internal",
      message: "AI provider call failed. Please try again.",
    });
  });
});

describe("generateContent region", () => {
  // Regression test: client (apps/web/src/lib/firebase.ts's
  // getFunctions(app, "asia-southeast1")) and server must agree on region,
  // or an onCall written without an explicit region option silently
  // defaults to us-central1 and becomes unreachable from the client.
  it("is configured for asia-southeast1, matching the client's getFunctions region", () => {
    expect(generateContent.__endpoint.region).toEqual(["asia-southeast1"]);
  });
});
