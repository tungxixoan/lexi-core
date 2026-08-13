import { describe, expect, it, vi } from "vitest";
import { callGroq, callOpenRouter } from "./openAiCompatible";
import { ProviderApiError } from "./types";

describe("callGroq", () => {
  it("calls the Groq chat completions endpoint with a Bearer token and returns the text", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ choices: [{ message: { content: "Xin chào từ Groq" } }] }),
    });

    const result = await callGroq(
      { apiKey: "secret-key", model: "llama-3.3-70b-versatile", prompt: "hi" },
      mockFetch as unknown as typeof fetch
    );

    expect(result).toEqual({ text: "Xin chào từ Groq" });
    const [url, options] = mockFetch.mock.calls[0];
    expect(url).toBe("https://api.groq.com/openai/v1/chat/completions");
    expect((options.headers as Record<string, string>).authorization).toBe(
      "Bearer secret-key"
    );
  });
});

describe("callOpenRouter", () => {
  it("calls the OpenRouter chat completions endpoint", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ choices: [{ message: { content: "hi from OpenRouter" } }] }),
    });

    const result = await callOpenRouter(
      { apiKey: "k", model: "meta-llama/llama-3.3-70b-instruct", prompt: "hi" },
      mockFetch as unknown as typeof fetch
    );

    expect(result).toEqual({ text: "hi from OpenRouter" });
    const [url] = mockFetch.mock.calls[0];
    expect(url).toBe("https://openrouter.ai/api/v1/chat/completions");
  });
});

describe("callOpenAiCompatible error mapping", () => {
  it("throws a ProviderApiError carrying the upstream status when the response is not ok (500)", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      text: async () => "internal server error, high demand",
    });
    let caught: unknown;
    try {
      await callGroq(
        { apiKey: "k", model: "llama-3.3-70b-versatile", prompt: "hi" },
        mockFetch as unknown as typeof fetch
      );
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(ProviderApiError);
    expect((caught as ProviderApiError).status).toBe(500);
  });
});
