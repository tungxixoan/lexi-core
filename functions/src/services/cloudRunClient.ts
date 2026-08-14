import { GoogleAuth } from "google-auth-library";
import { HttpsError } from "firebase-functions/v2/https";

function getAuth(): GoogleAuth {
  return new GoogleAuth();
}

export class CloudRunCallError extends Error {
  constructor(
    message: string,
    readonly status?: number
  ) {
    super(message);
    this.name = "CloudRunCallError";
  }
}

interface CloudRunRequestOptions {
  path: string;
  body: BodyInit | Record<string, unknown> | Buffer;
  headers: Record<string, string>;
  responseType: "json" | "arraybuffer";
}

async function callCloudRun<T>(serviceUrl: string, options: CloudRunRequestOptions): Promise<T> {
  const url = `${serviceUrl}${options.path}`;
  try {
    if (serviceUrl.startsWith("http://")) {
      // Local dev against `uvicorn app.main:app` — no IAM identity token available there.
      const res = await fetch(url, {
        method: "POST",
        headers: options.headers,
        body: options.body as BodyInit,
      });
      if (!res.ok) {
        throw new CloudRunCallError(`Cloud Run service returned ${res.status}`, res.status);
      }
      return options.responseType === "arraybuffer"
        ? (Buffer.from(await res.arrayBuffer()) as unknown as T)
        : ((await res.json()) as T);
    }

    const client = await getAuth().getIdTokenClient(serviceUrl);
    const res = await client.request<T>({
      url,
      method: "POST",
      data: options.body,
      headers: options.headers,
      responseType: options.responseType,
    });
    return res.data;
  } catch (err) {
    if (err instanceof CloudRunCallError) {
      throw err;
    }
    const status = (err as { response?: { status?: number } })?.response?.status;
    throw new CloudRunCallError(err instanceof Error ? err.message : String(err), status);
  }
}

export async function synthesizeViaCloudRun(
  serviceUrl: string,
  text: string,
  language: "vi" | "en"
): Promise<Buffer> {
  const data = await callCloudRun<ArrayBuffer | Buffer>(serviceUrl, {
    path: "/synthesize",
    body: JSON.stringify({ text, language }),
    headers: { "Content-Type": "application/json" },
    responseType: "arraybuffer",
  });
  return Buffer.isBuffer(data) ? data : Buffer.from(data);
}

export async function transcribeViaCloudRun(
  serviceUrl: string,
  audio: Buffer,
  language?: string
): Promise<{ text: string; language: string }> {
  const query = language ? `?language=${encodeURIComponent(language)}` : "";
  return callCloudRun<{ text: string; language: string }>(serviceUrl, {
    path: `/transcribe${query}`,
    body: audio,
    headers: { "Content-Type": "audio/wav" },
    responseType: "json",
  });
}

export function toHttpsError(err: unknown, fallbackMessage: string): HttpsError {
  if (err instanceof HttpsError) {
    return err;
  }
  if (err instanceof CloudRunCallError && (err.status === 503 || err.status === 504)) {
    return new HttpsError(
      "unavailable",
      "TTS/STT service is warming up or busy. Try again in a moment."
    );
  }
  return new HttpsError("internal", fallbackMessage);
}
