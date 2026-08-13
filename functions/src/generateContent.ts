import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { callGemini } from "./providers/gemini";
import { callGroq, callOpenRouter } from "./providers/openAiCompatible";
import { ProviderApiError, type GenerateContentResult } from "./providers/types";

// Keep this in sync with the client-side type of the same name in
// apps/web/src/lib/generateContent.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export type AiProvider = "gemini" | "groq" | "openrouter";

// Keep this in sync with the client-side type of the same name in
// apps/web/src/lib/generateContent.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export interface GenerateContentRequest {
  provider: AiProvider;
  apiKey: string;
  model: string;
  prompt: string;
}

function isGenerateContentRequest(data: unknown): data is GenerateContentRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    (d.provider === "gemini" || d.provider === "groq" || d.provider === "openrouter") &&
    typeof d.apiKey === "string" &&
    d.apiKey.length > 0 &&
    typeof d.model === "string" &&
    d.model.length > 0 &&
    typeof d.prompt === "string" &&
    d.prompt.length > 0
  );
}

export async function generateContentHandler(
  request: CallableRequest<unknown>
): Promise<GenerateContentResult> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isGenerateContentRequest(request.data)) {
    throw new HttpsError(
      "invalid-argument",
      "Expected { provider, apiKey, model, prompt } (all non-empty strings)."
    );
  }

  const { provider, ...params } = request.data;

  try {
    switch (provider) {
      case "gemini":
        return await callGemini(params);
      case "groq":
        return await callGroq(params);
      case "openrouter":
        return await callOpenRouter(params);
      default: {
        const exhaustiveCheck: never = provider;
        throw new HttpsError("invalid-argument", `Unknown provider: ${exhaustiveCheck}`);
      }
    }
  } catch (err) {
    if (err instanceof HttpsError) {
      throw err;
    }
    logger.error(`AI provider call failed (provider: ${provider})`, {
      provider,
      error: err instanceof Error ? err.message : String(err),
    });

    if (err instanceof ProviderApiError) {
      const status = err.status;
      if (status === 401 || status === 403) {
        throw new HttpsError(
          "permission-denied",
          "Provider rejected the API key. Check it's correct and active."
        );
      }
      if (status === 429) {
        throw new HttpsError(
          "resource-exhausted",
          "Provider rate limit or quota exceeded. Try again shortly."
        );
      }
      if (status !== undefined && status >= 500 && status <= 599) {
        throw new HttpsError(
          "unavailable",
          "Provider is temporarily unavailable. Try again in a moment."
        );
      }
    }

    throw new HttpsError("internal", "AI provider call failed. Please try again.");
  }
}

export const generateContent = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 120 },
  generateContentHandler
);
