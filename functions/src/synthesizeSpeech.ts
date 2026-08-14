import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { synthesizeViaCloudRun, toHttpsError } from "./services/cloudRunClient";

export interface SynthesizeSpeechRequest {
  text: string;
  language: "vi" | "en";
}

function isSynthesizeSpeechRequest(data: unknown): data is SynthesizeSpeechRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    typeof d.text === "string" &&
    d.text.trim().length > 0 &&
    (d.language === "vi" || d.language === "en")
  );
}

export async function synthesizeSpeechHandler(
  request: CallableRequest<unknown>
): Promise<{ audioBase64: string }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isSynthesizeSpeechRequest(request.data)) {
    throw new HttpsError("invalid-argument", "Expected { text, language: 'vi'|'en' }.");
  }
  const serviceUrl = process.env.TTS_STT_SERVICE_URL ?? "";
  if (!serviceUrl) {
    throw new HttpsError("failed-precondition", "TTS/STT service URL is not configured.");
  }

  try {
    const audio = await synthesizeViaCloudRun(serviceUrl, request.data.text, request.data.language);
    return { audioBase64: audio.toString("base64") };
  } catch (err) {
    throw toHttpsError(err, "Speech synthesis failed. Please try again.");
  }
}

export const synthesizeSpeech = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 60 },
  synthesizeSpeechHandler
);
