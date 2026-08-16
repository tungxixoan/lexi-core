import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";

// Keep this in sync with the server-side type of the same name in
// functions/src/encryptApiKey.ts.
export interface EncryptApiKeyRequest {
  apiKey: string;
}

export interface EncryptApiKeyResult {
  ciphertext: string;
}

export async function encryptApiKey(
  request: EncryptApiKeyRequest
): Promise<EncryptApiKeyResult> {
  const callable = httpsCallable<EncryptApiKeyRequest, EncryptApiKeyResult>(
    getFirebaseFunctions(),
    "encryptApiKey"
  );
  const response = await callable(request);
  return response.data;
}
