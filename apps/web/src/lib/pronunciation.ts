import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";
import type { TargetLanguage } from "./languages";

export type TtsLanguage = "vi" | "en";

// The self-hosted Piper TTS service only has voices deployed for Vietnamese
// and English (functions/src/getPronunciation.ts's VOICE_IDS) — null means
// no pronunciation audio is available yet for this target language.
export function ttsLanguageCode(targetLanguage: TargetLanguage): TtsLanguage | null {
  if (targetLanguage === "vietnamese") return "vi";
  if (targetLanguage === "english") return "en";
  return null;
}

// Keep in sync with functions/src/getPronunciation.ts's GetPronunciationRequest
// (no shared-types package yet).
export interface GetPronunciationRequest {
  text: string;
  language: TtsLanguage;
  tier: "word" | "sentence";
}

export async function getPronunciationUrl(request: GetPronunciationRequest): Promise<string> {
  const callable = httpsCallable<GetPronunciationRequest, { url: string }>(
    getFirebaseFunctions(),
    "getPronunciation"
  );
  const response = await callable(request);
  return response.data.url;
}
