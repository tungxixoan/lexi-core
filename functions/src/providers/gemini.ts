import { ProviderApiError, type GenerateContentParams, type GenerateContentResult } from "./types";

interface GeminiResponse {
  candidates?: Array<{
    content?: { parts?: Array<{ text?: string }> };
  }>;
}

export async function callGemini(
  { apiKey, model, prompt }: GenerateContentParams,
  fetchImpl: typeof fetch = fetch
): Promise<GenerateContentResult> {
  const response = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
      }),
    }
  );

  if (!response.ok) {
    throw new ProviderApiError(
      `Gemini API error: ${response.status} ${await response.text()}`,
      response.status
    );
  }

  const data = (await response.json()) as GeminiResponse;
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Gemini API returned no text.");
  }
  return { text };
}
