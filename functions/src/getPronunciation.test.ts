import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";

vi.mock("firebase-admin/app", () => ({ getApps: () => [{}], initializeApp: vi.fn() }));
vi.mock("firebase-admin/storage", () => ({
  getStorage: vi.fn().mockReturnValue({ bucket: () => ({ name: "lexi-core.firebasestorage.app" }) }),
}));
vi.mock("./services/pronunciationCache", () => ({
  getOrCreatePronunciation: vi.fn(),
}));

import { getOrCreatePronunciation } from "./services/pronunciationCache";
import { getPronunciationHandler, getPronunciation } from "./getPronunciation";

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
});

function makeRequest(data: unknown, authed = true): CallableRequest<unknown> {
  return {
    auth: authed ? { uid: "user-123" } : undefined,
    data,
  } as CallableRequest<unknown>;
}

describe("getPronunciationHandler", () => {
  it("throws unauthenticated when there is no auth context", async () => {
    await expect(
      getPronunciationHandler(makeRequest({ text: "a", language: "vi", tier: "word" }, false))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("throws invalid-argument for a malformed payload", async () => {
    await expect(
      getPronunciationHandler(makeRequest({ text: "", language: "vi", tier: "word" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws invalid-argument for text over 500 characters", async () => {
    await expect(
      getPronunciationHandler(
        makeRequest({ text: "a".repeat(501), language: "vi", tier: "word" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws failed-precondition when TTS_STT_SERVICE_URL is unset", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "");
    await expect(
      getPronunciationHandler(makeRequest({ text: "chào", language: "vi", tier: "word" }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("returns the cache URL for a valid request", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(getOrCreatePronunciation).mockResolvedValue(
      "https://firebasestorage.googleapis.com/x?alt=media"
    );

    const result = await getPronunciationHandler(
      makeRequest({ text: "chào", language: "vi", tier: "word" })
    );

    expect(getOrCreatePronunciation).toHaveBeenCalledWith(
      { name: "lexi-core.firebasestorage.app" },
      "https://tts-stt.a.run.app",
      { tier: "word", language: "vi", voiceId: "vi_VN-vais1000-medium", text: "chào" }
    );
    expect(result).toEqual({ url: "https://firebasestorage.googleapis.com/x?alt=media" });
  });
});

describe("getPronunciation region", () => {
  // Regression test: client (apps/web/src/lib/firebase.ts's
  // getFunctions(app, "asia-southeast1")) and server must agree on region,
  // or an onCall written without an explicit region option silently
  // defaults to us-central1 and becomes unreachable from the client.
  it("is configured for asia-southeast1, matching the client's getFunctions region", () => {
    expect(getPronunciation.__endpoint.region).toEqual(["asia-southeast1"]);
  });
});
