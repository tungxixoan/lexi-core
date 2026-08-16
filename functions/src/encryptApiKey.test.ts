import { describe, expect, it, vi } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";

vi.mock("./services/kms", () => ({ encryptWithKms: vi.fn() }));

import { encryptWithKms } from "./services/kms";
import { encryptApiKeyHandler, encryptApiKey } from "./encryptApiKey";

function makeRequest(data: unknown, authed = true): CallableRequest<unknown> {
  return {
    auth: authed ? { uid: "user-123" } : undefined,
    data,
  } as CallableRequest<unknown>;
}

describe("encryptApiKeyHandler", () => {
  it("throws unauthenticated when there is no auth context", async () => {
    await expect(
      encryptApiKeyHandler(makeRequest({ apiKey: "sk-abc" }, false))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("throws invalid-argument for a missing/empty apiKey", async () => {
    await expect(
      encryptApiKeyHandler(makeRequest({ apiKey: "" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(encryptApiKeyHandler(makeRequest({}))).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  it("returns the ciphertext from encryptWithKms for a valid request", async () => {
    vi.mocked(encryptWithKms).mockResolvedValue("ciphertext-base64");
    const result = await encryptApiKeyHandler(makeRequest({ apiKey: "sk-abc" }));
    expect(encryptWithKms).toHaveBeenCalledWith("sk-abc", "user-123");
    expect(result).toEqual({ ciphertext: "ciphertext-base64" });
  });

  it("wraps a KMS failure in an internal HttpsError without leaking details", async () => {
    vi.mocked(encryptWithKms).mockRejectedValue(new Error("KMS key not found: projects/..."));
    let caught: unknown;
    try {
      await encryptApiKeyHandler(makeRequest({ apiKey: "sk-abc" }));
    } catch (err) {
      caught = err;
    }
    expect(caught).toMatchObject({
      code: "internal",
      message: "Failed to encrypt API key. Please try again.",
    });
  });
});

describe("encryptApiKey region", () => {
  // Regression test: client (apps/web/src/lib/firebase.ts's
  // getFunctions(app, "asia-southeast1")) and server must agree on region,
  // or an onCall written without an explicit region option silently
  // defaults to us-central1 and becomes unreachable from the client.
  it("is configured for asia-southeast1, matching the client's getFunctions region", () => {
    expect(encryptApiKey.__endpoint.region).toEqual(["asia-southeast1"]);
  });
});
