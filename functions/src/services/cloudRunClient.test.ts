import { afterEach, describe, expect, it, vi } from "vitest";
import { HttpsError } from "firebase-functions/v2/https";

const getIdTokenClientMock = vi.fn();

vi.mock("google-auth-library", () => {
  const GoogleAuthClass = class {
    getIdTokenClient: any;
    constructor() {
      this.getIdTokenClient = getIdTokenClientMock;
    }
  };
  return {
    GoogleAuth: GoogleAuthClass,
  };
});

import {
  CloudRunCallError,
  synthesizeViaCloudRun,
  transcribeViaCloudRun,
  toHttpsError,
} from "./cloudRunClient";

afterEach(() => {
  getIdTokenClientMock.mockClear();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("synthesizeViaCloudRun", () => {
  it("mints an ID token and returns audio bytes for an https service URL", async () => {
    const requestMock = vi.fn().mockResolvedValue({ data: Buffer.from("wav-bytes") });
    getIdTokenClientMock.mockResolvedValue({ request: requestMock });

    const result = await synthesizeViaCloudRun("https://tts-stt-abc.a.run.app", "xin chao", "vi");

    expect(getIdTokenClientMock).toHaveBeenCalledWith("https://tts-stt-abc.a.run.app");
    expect(requestMock).toHaveBeenCalledWith(
      expect.objectContaining({
        url: "https://tts-stt-abc.a.run.app/synthesize",
        method: "POST",
        responseType: "arraybuffer",
      })
    );
    expect(result).toEqual(Buffer.from("wav-bytes"));
  });

  it("skips IAM auth for a local http service URL", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => new TextEncoder().encode("wav-bytes").buffer,
    });
    vi.stubGlobal("fetch", fetchMock);

    const result = await synthesizeViaCloudRun("http://localhost:8080", "xin chao", "vi");

    expect(getIdTokenClientMock).not.toHaveBeenCalled();
    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:8080/synthesize",
      expect.objectContaining({ method: "POST" })
    );
    expect(Buffer.from(result).toString()).toBe("wav-bytes");
  });

  it("wraps a non-2xx response as CloudRunCallError with status", async () => {
    const requestMock = vi.fn().mockRejectedValue({
      response: { status: 503 },
      message: "Service Unavailable",
    });
    getIdTokenClientMock.mockResolvedValue({ request: requestMock });

    await expect(
      synthesizeViaCloudRun("https://tts-stt-abc.a.run.app", "xin chao", "vi")
    ).rejects.toMatchObject({ status: 503 });
  });
});

describe("transcribeViaCloudRun", () => {
  it("posts audio bytes and returns the transcript JSON", async () => {
    const requestMock = vi.fn().mockResolvedValue({ data: { text: "xin chao", language: "vi" } });
    getIdTokenClientMock.mockResolvedValue({ request: requestMock });

    const result = await transcribeViaCloudRun(
      "https://tts-stt-abc.a.run.app",
      Buffer.from("wav-bytes"),
      "vi"
    );

    expect(requestMock).toHaveBeenCalledWith(
      expect.objectContaining({
        url: "https://tts-stt-abc.a.run.app/transcribe?language=vi",
        method: "POST",
      })
    );
    expect(result).toEqual({ text: "xin chao", language: "vi" });
  });
});

describe("toHttpsError", () => {
  it("passes an existing HttpsError through unchanged", () => {
    const original = new HttpsError("invalid-argument", "bad input");
    expect(toHttpsError(original, "fallback")).toBe(original);
  });

  it("maps a 503/504 CloudRunCallError to 'unavailable'", () => {
    const mapped = toHttpsError(new CloudRunCallError("boom", 503), "fallback");
    expect(mapped.code).toBe("unavailable");
  });

  it("maps any other error to 'internal' with the fallback message", () => {
    const mapped = toHttpsError(new Error("boom"), "fallback message");
    expect(mapped.code).toBe("internal");
    expect(mapped.message).toBe("fallback message");
  });
});
