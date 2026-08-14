import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { transcribeViaCloudRun, toHttpsError } from "./services/cloudRunClient";

export interface TranscribeAudioRequest {
  audioBase64: string;
  language?: "vi" | "en";
}

function isTranscribeAudioRequest(data: unknown): data is TranscribeAudioRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    typeof d.audioBase64 === "string" &&
    d.audioBase64.length > 0 &&
    (d.language === undefined || d.language === "vi" || d.language === "en")
  );
}

export async function transcribeAudioHandler(
  request: CallableRequest<unknown>
): Promise<{ text: string; language: string }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isTranscribeAudioRequest(request.data)) {
    throw new HttpsError(
      "invalid-argument",
      "Expected { audioBase64: string, language?: 'vi'|'en' }."
    );
  }
  const serviceUrl = process.env.TTS_STT_SERVICE_URL ?? "";
  if (!serviceUrl) {
    throw new HttpsError("failed-precondition", "TTS/STT service URL is not configured.");
  }

  try {
    const audio = Buffer.from(request.data.audioBase64, "base64");
    return await transcribeViaCloudRun(serviceUrl, audio, request.data.language);
  } catch (err) {
    throw toHttpsError(err, "Transcription failed. Please try again.");
  }
}

export const transcribeAudio = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 60 },
  transcribeAudioHandler
);
