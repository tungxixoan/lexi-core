export interface GenerateContentParams {
  apiKey: string;
  model: string;
  prompt: string;
}

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
