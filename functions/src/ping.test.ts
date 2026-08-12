import { describe, expect, it } from "vitest";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { pingHandler } from "./ping";

describe("pingHandler", () => {
  it("returns a pong message including the caller's uid when signed in", () => {
    const request = { auth: { uid: "user-123" } } as CallableRequest<unknown>;
    const result = pingHandler(request);
    expect(result).toEqual({ message: "pong, user-123" });
  });

  it("throws unauthenticated when there is no auth context", () => {
    const request = { auth: undefined } as CallableRequest<unknown>;
    expect(() => pingHandler(request)).toThrow(HttpsError);
  });
});
