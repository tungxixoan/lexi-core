import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";

export function pingHandler(request: CallableRequest<unknown>) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return { message: `pong, ${request.auth.uid}` };
}

export const ping = onCall({ region: "asia-southeast1" }, pingHandler);
