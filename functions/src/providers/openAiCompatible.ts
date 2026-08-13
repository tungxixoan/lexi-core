import type { GenerateContentParams, GenerateContentResult } from "./types";

interface ChatCompletionsResponse {
  choices?: Array<{ message?: { content?: string } }>;
}

export async function callOpenAiCompatible(
  baseUrl: string,
  { apiKey, model, prompt }: GenerateContentParams,
  fetchImpl: typeof fetch = fetch
): Promise<GenerateContentResult> {
  const response = await fetchImpl(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    throw new Error(`${baseUrl} API error: ${response.status} ${await response.text()}`);
  }

  const data = (await response.json()) as ChatCompletionsResponse;
  const text = data.choices?.[0]?.message?.content;
  if (!text) {
    throw new Error(`${baseUrl} API returned no text.`);
  }
  return { text };
}

export function callGroq(
  params: GenerateContentParams,
  fetchImpl?: typeof fetch
): Promise<GenerateContentResult> {
  return callOpenAiCompatible("https://api.groq.com/openai/v1", params, fetchImpl);
}

export function callOpenRouter(
  params: GenerateContentParams,
  fetchImpl?: typeof fetch
): Promise<GenerateContentResult> {
  return callOpenAiCompatible("https://openrouter.ai/api/v1", params, fetchImpl);
}
