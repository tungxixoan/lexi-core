import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";

vi.mock("./services/cloudRunClient", async () => {
  const actual = await vi.importActual<typeof import("./services/cloudRunClient")>(
    "./services/cloudRunClient"
  );
  return { ...actual, synthesizeViaCloudRun: vi.fn() };
});

import { synthesizeViaCloudRun } from "./services/cloudRunClient";
import { synthesizeSpeechHandler } from "./synthesizeSpeech";

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

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith("https://tts-stt.a.run.app", "hi", "vi");
    expect(result).toEqual({ audioBase64: Buffer.from("wav-bytes").toString("base64") });
  });

  it("maps a Cloud Run failure to HttpsError", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockRejectedValue(new Error("boom"));

    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }))
    ).rejects.toMatchObject({ code: "internal" });
  });
});
