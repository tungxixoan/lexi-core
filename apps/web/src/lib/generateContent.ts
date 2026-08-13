import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";

// Keep this in sync with the server-side type of the same name in
// functions/src/generateContent.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export type AiProvider = "gemini" | "groq" | "openrouter";

// Keep this in sync with the server-side type of the same name in
// functions/src/generateContent.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export interface GenerateContentRequest {
  provider: AiProvider;
  apiKey: string;
  model: string;
  prompt: string;
}

// Keep this in sync with the server-side type of the same name in
// functions/src/providers/types.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export interface GenerateContentResult {
  text: string;
}

export async function generateContent(
  request: GenerateContentRequest
): Promise<GenerateContentResult> {
  const callable = httpsCallable<GenerateContentRequest, GenerateContentResult>(
    getFirebaseFunctions(),
    "generateContent"
  );
  const response = await callable(request);
  return response.data;
}
