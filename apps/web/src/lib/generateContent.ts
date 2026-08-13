import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";

export type AiProvider = "gemini" | "groq" | "openrouter";

export interface GenerateContentRequest {
  provider: AiProvider;
  apiKey: string;
  model: string;
  prompt: string;
}

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
