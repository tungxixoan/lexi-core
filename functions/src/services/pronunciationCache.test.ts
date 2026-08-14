import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("./cloudRunClient", () => ({
  synthesizeViaCloudRun: vi.fn(),
}));

import { synthesizeViaCloudRun } from "./cloudRunClient";
import {
  cachePath,
  getOrCreatePronunciation,
  publicDownloadUrl,
  type MinimalCacheBucket,
} from "./pronunciationCache";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("cachePath", () => {
  it("is deterministic for identical text/language/voice", () => {
    const key = {
      tier: "word" as const,
      language: "vi" as const,
      voiceId: "vi_VN-vais1000-medium",
      text: "xin chào",
    };
    expect(cachePath(key)).toBe(cachePath({ ...key }));
  });

  it("differs when the text differs", () => {
    const base = {
      tier: "word" as const,
      language: "vi" as const,
      voiceId: "vi_VN-vais1000-medium",
    };
    expect(cachePath({ ...base, text: "xin chào" })).not.toBe(
      cachePath({ ...base, text: "tạm biệt" })
    );
  });

  it("ignores surrounding whitespace differences", () => {
    const base = { tier: "sentence" as const, language: "en" as const, voiceId: "en_US-lessac-medium" };
    expect(cachePath({ ...base, text: "hello world" })).toBe(
      cachePath({ ...base, text: "  hello world  " })
    );
  });

  it("nests under tier/language/voiceId", () => {
    const path = cachePath({
      tier: "word",
      language: "vi",
      voiceId: "vi_VN-vais1000-medium",
      text: "chào",
    });
    expect(path).toMatch(/^tts-cache\/word\/vi\/vi_VN-vais1000-medium\/[0-9a-f]{64}\.wav$/);
  });
});

describe("publicDownloadUrl", () => {
  it("builds a Firebase Storage download URL with an encoded path", () => {
    const url = publicDownloadUrl("lexi-core.appspot.com", "tts-cache/word/vi/x/abc.wav");
    expect(url).toBe(
      "https://firebasestorage.googleapis.com/v0/b/lexi-core.appspot.com/o/tts-cache%2Fword%2Fvi%2Fx%2Fabc.wav?alt=media"
    );
  });
});

function fakeBucket(exists: boolean) {
  const save = vi.fn().mockResolvedValue(undefined);
  const file = vi.fn().mockReturnValue({
    exists: vi.fn().mockResolvedValue([exists]),
    save,
  });
  const bucket: MinimalCacheBucket = { name: "lexi-core.appspot.com", file };
  return { bucket, file, save };
}

describe("getOrCreatePronunciation", () => {
  it("returns the cached URL without calling Cloud Run on a hit", async () => {
    const { bucket, save } = fakeBucket(true);

    const url = await getOrCreatePronunciation(bucket, "https://tts-stt.a.run.app", {
      tier: "word",
      language: "vi",
      voiceId: "vi_VN-vais1000-medium",
      text: "chào",
    });

    expect(synthesizeViaCloudRun).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();
    expect(url).toContain("alt=media");
  });

  it("synthesizes and uploads on a miss", async () => {
    const { bucket, save } = fakeBucket(false);
    vi.mocked(synthesizeViaCloudRun).mockResolvedValue(Buffer.from("wav-bytes"));

    await getOrCreatePronunciation(bucket, "https://tts-stt.a.run.app", {
      tier: "sentence",
      language: "en",
      voiceId: "en_US-lessac-medium",
      text: "hello",
    });

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith("https://tts-stt.a.run.app", "hello", "en");
    expect(save).toHaveBeenCalledWith(Buffer.from("wav-bytes"), {
      metadata: { contentType: "audio/wav" },
    });
  });
});
