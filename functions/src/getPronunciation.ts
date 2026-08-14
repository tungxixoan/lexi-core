import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { getApps, initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { toHttpsError } from "./services/cloudRunClient";
import { getOrCreatePronunciation, type PronunciationTier } from "./services/pronunciationCache";

if (getApps().length === 0) {
  initializeApp();
}

const VOICE_IDS: Record<"vi" | "en", string> = {
  vi: "vi_VN-vais1000-medium",
  en: "en_US-lessac-medium",
};

export interface GetPronunciationRequest {
  text: string;
  language: "vi" | "en";
  tier: PronunciationTier;
}

function isGetPronunciationRequest(data: unknown): data is GetPronunciationRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    typeof d.text === "string" &&
    d.text.trim().length > 0 &&
    (d.language === "vi" || d.language === "en") &&
    (d.tier === "word" || d.tier === "sentence")
  );
}

export async function getPronunciationHandler(
  request: CallableRequest<unknown>
): Promise<{ url: string }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isGetPronunciationRequest(request.data)) {
    throw new HttpsError(
      "invalid-argument",
      "Expected { text, language: 'vi'|'en', tier: 'word'|'sentence' }."
    );
  }
  const serviceUrl = process.env.TTS_STT_SERVICE_URL ?? "";
  if (!serviceUrl) {
    throw new HttpsError("failed-precondition", "TTS/STT service URL is not configured.");
  }

  const { text, language, tier } = request.data;

  try {
    const url = await getOrCreatePronunciation(getStorage().bucket(), serviceUrl, {
      tier,
      language,
      voiceId: VOICE_IDS[language],
      text,
    });
    return { url };
  } catch (err) {
    throw toHttpsError(err, "Pronunciation generation failed. Please try again.");
  }
}

export const getPronunciation = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 30 },
  getPronunciationHandler
);
