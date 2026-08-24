import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";

vi.mock("./services/cloudRunClient", async () => {
  const actual = await vi.importActual<typeof import("./services/cloudRunClient")>(
    "./services/cloudRunClient"
  );
  return { ...actual, synthesizeViaCloudRun: vi.fn() };
});

import { synthesizeViaCloudRun } from "./services/cloudRunClient";
import { synthesizeSpeechHandler, synthesizeSpeech } from "./synthesizeSpeech";

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

describe("synthesizeSpeechHandler", () => {
  it("throws unauthenticated when there is no auth context", async () => {
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }, false))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("throws invalid-argument for a malformed payload", async () => {
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "", language: "vi" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws invalid-argument for text over 500 characters", async () => {
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "a".repeat(501), language: "vi" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws failed-precondition when TTS_STT_SERVICE_URL is unset", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "");
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("returns base64 audio for a valid request", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockResolvedValue(Buffer.from("wav-bytes"));

    const result = await synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }));

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith(
      "https://tts-stt.a.run.app",
      "hi",
      "vi",
      undefined
    );
    expect(result).toEqual({ audioBase64: Buffer.from("wav-bytes").toString("base64") });
  });

  it("maps a Cloud Run failure to HttpsError", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockRejectedValue(new Error("boom"));

    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }))
    ).rejects.toMatchObject({ code: "internal" });
  });

  it("accepts an optional voice field and threads it through to Cloud Run", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockResolvedValue(Buffer.from("wav-bytes"));

    await synthesizeSpeechHandler(makeRequest({ text: "hi", language: "en", voice: "male1" }));

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith(
      "https://tts-stt.a.run.app",
      "hi",
      "en",
      "male1"
    );
  });

  it("omits voice when the caller doesn't send one — existing callers unaffected", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockResolvedValue(Buffer.from("wav-bytes"));

    await synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }));

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith(
      "https://tts-stt.a.run.app",
      "hi",
      "vi",
      undefined
    );
  });

  it("throws invalid-argument for an unrecognized voice value", async () => {
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "en", voice: "not-a-voice" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

describe("synthesizeSpeech region", () => {
  // Regression test: client (apps/web/src/lib/firebase.ts's
  // getFunctions(app, "asia-southeast1")) and server must agree on region,
  // or an onCall written without an explicit region option silently
  // defaults to us-central1 and becomes unreachable from the client.
  it("is configured for asia-southeast1, matching the client's getFunctions region", () => {
    expect(synthesizeSpeech.__endpoint.region).toEqual(["asia-southeast1"]);
  });
});
