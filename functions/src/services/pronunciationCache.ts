import { createHash } from "node:crypto";
import { synthesizeViaCloudRun } from "./cloudRunClient";

export type PronunciationTier = "word" | "sentence";

export interface PronunciationCacheKey {
  tier: PronunciationTier;
  language: "vi" | "en";
  voiceId: string;
  text: string;
}

export interface MinimalCacheFile {
  exists(): Promise<[boolean]>;
  save(data: Buffer, options: { metadata: { contentType: string } }): Promise<void>;
}

export interface MinimalCacheBucket {
  name: string;
  file(path: string): MinimalCacheFile;
}

function normalize(text: string): string {
  return text.trim().normalize("NFC");
}

export function cachePath({ tier, language, voiceId, text }: PronunciationCacheKey): string {
  const hash = createHash("sha256")
    .update(normalize(text) + language + voiceId)
    .digest("hex");
  return `tts-cache/${tier}/${language}/${voiceId}/${hash}.wav`;
}

export function publicDownloadUrl(bucketName: string, path: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(path)}?alt=media`;
}

export async function getOrCreatePronunciation(
  bucket: MinimalCacheBucket,
  serviceUrl: string,
  key: PronunciationCacheKey
): Promise<string> {
  const path = cachePath(key);
  const file = bucket.file(path);
  const [exists] = await file.exists();
  if (!exists) {
    const audio = await synthesizeViaCloudRun(serviceUrl, key.text, key.language);
    await file.save(audio, { metadata: { contentType: "audio/wav" } });
  }
  return publicDownloadUrl(bucket.name, path);
}
