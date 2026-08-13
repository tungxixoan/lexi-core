export interface GenerateContentParams {
  apiKey: string;
  model: string;
  prompt: string;
}

// Keep this in sync with the client-side type of the same name in
// apps/web/src/lib/generateContent.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export interface GenerateContentResult {
  text: string;
}

/**
 * Thrown when an upstream AI provider's HTTP response is not ok, carrying
 * the upstream status code so generateContent.ts can map it to a specific
 * HttpsError code (e.g. 401/403 -> permission-denied, 429 ->
 * resource-exhausted, 5xx -> unavailable) without echoing any response body
 * to the client.
 */
export class ProviderApiError extends Error {
  readonly status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = "ProviderApiError";
    this.status = status;
  }
}
