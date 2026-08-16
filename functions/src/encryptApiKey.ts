import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { encryptWithKms } from "./services/kms";

export interface EncryptApiKeyRequest {
  apiKey: string;
}

export interface EncryptApiKeyResult {
  ciphertext: string;
}

function isEncryptApiKeyRequest(data: unknown): data is EncryptApiKeyRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return typeof d.apiKey === "string" && d.apiKey.trim().length > 0;
}

export async function encryptApiKeyHandler(
  request: CallableRequest<unknown>
): Promise<EncryptApiKeyResult> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isEncryptApiKeyRequest(request.data)) {
    throw new HttpsError("invalid-argument", "Expected { apiKey: string } (non-empty).");
  }

  try {
    const ciphertext = await encryptWithKms(request.data.apiKey, request.auth.uid);
    return { ciphertext };
  } catch {
    throw new HttpsError("internal", "Failed to encrypt API key. Please try again.");
  }
}

export const encryptApiKey = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 30 },
  encryptApiKeyHandler
);
