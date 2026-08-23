import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";

// Keep this in sync with the server-side type of the same name in
// functions/src/synthesizeSpeech.ts (no shared-types package yet — same
// convention as generateContent.ts).
export interface SynthesizeSpeechRequest {
  text: string;
  language: "vi" | "en";
}

export interface SynthesizeSpeechResult {
  audioBase64: string;
}

export async function synthesizeSpeech(
  request: SynthesizeSpeechRequest
): Promise<SynthesizeSpeechResult> {
  const callable = httpsCallable<SynthesizeSpeechRequest, SynthesizeSpeechResult>(
    getFirebaseFunctions(),
    "synthesizeSpeech"
  );
  const response = await callable(request);
  return response.data;
}

// Piper's Cloud Run response is served with Content-Type: audio/wav
// (functions/src/services/cloudRunClient.ts) — every caller in this app
// builds its playable URL through this one helper so that format is never
// duplicated/guessed at call sites.
export function toAudioDataUrl(audioBase64: string): string {
  return `data:audio/wav;base64,${audioBase64}`;
}
