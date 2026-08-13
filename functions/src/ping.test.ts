import { describe, expect, it } from "vitest";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { pingHandler, ping } from "./ping";

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

describe("ping region", () => {
  // Regression test: client (apps/web/src/lib/firebase.ts's
  // getFunctions(app, "asia-southeast1")) and server must agree on region,
  // or an onCall written without an explicit region option silently
  // defaults to us-central1 and becomes unreachable from the client.
  it("is configured for asia-southeast1, matching the client's getFunctions region", () => {
    expect(ping.__endpoint.region).toEqual(["asia-southeast1"]);
  });
});
