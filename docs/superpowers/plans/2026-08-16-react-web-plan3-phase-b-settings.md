# React Web Plan 3 / Phase B (Part 1) — Cài đặt (Settings) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Task 9 is deployment/live-infra work and must NOT be dispatched to a subagent** — do it directly with the user, mirroring React Web Plan 2's Task 9.

**Goal:** Give the Next.js web app (`apps/web/`) a working `/settings` screen so the user can persist their AI provider, model, and BYOK API key once (encrypted via Cloud KMS) instead of re-entering it every session — the hard prerequisite for the next sub-spec (Tra từ + Luyện tập, both of which call `generateContent` repeatedly.

**Architecture:** A new Firestore doc `users/{uid}/settings/config` holds the user's active provider, per-provider model + encrypted API key ciphertext, theme, and font-size — read/written client-side via the Firebase JS SDK (matching the existing `vocab_records`/`topics` pattern). Two new Cloud Functions: `encryptApiKey` (onCall, wraps Google Cloud KMS `encrypt`) and a modified `generateContent` (accepts either a raw `apiKey` as today, or a new `apiKeyCiphertext` field it decrypts via KMS in-memory before the upstream LLM call). The client never runs any cryptography itself.

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12, Vitest + React Testing Library + jsdom (existing setup); Firebase Cloud Functions 2nd gen (Node 22) in `functions/`, Vitest; new dependency `@google-cloud/kms`.

## Global Constraints

- All user-facing text is Vietnamese, matching every existing screen.
- Import alias `@/` maps to `apps/web/src/` — use it for all cross-file web imports.
- Every new/changed file gets a colocated Vitest test (`*.test.ts` / `*.test.tsx`), following the existing mock style: `vi.mock("firebase/firestore", ...)`, `vi.mock("./firebase", () => ({ getFirebaseDb: vi.fn(() => "mock-db") }))` on the web side; `vi.mock(...)` per-dependency on the functions side (see `functions/src/getPronunciation.test.ts` for the pattern).
- Both `getFunctions`/`onCall` sides must agree on region `asia-southeast1` — every new/modified `onCall` function must pass `{ region: "asia-southeast1" }` and get a region-regression test (see `functions/src/getPronunciation.test.ts`'s `"is configured for asia-southeast1..."` test for the pattern).
- The BYOK API key is never logged. `generateContent`'s existing behavior of not leaking raw upstream provider errors to the client is unchanged (do not regress the existing tests that assert this).
- Duplicated client/server TypeScript types (the `// Keep this in sync with...` comment convention already used by `GenerateContentRequest`) must be kept in sync across `functions/src/generateContent.ts` and `apps/web/src/lib/generateContent.ts`.
- Verify each task with `npm --prefix functions test` and/or `npm --prefix apps/web test` (whichever side it touches) and finish the plan with `npm --prefix functions run typecheck`, `npm --prefix apps/web run typecheck`, and `npm --prefix apps/web run build`.

---

## Task 1: Cloud KMS service module + `encryptApiKey` Cloud Function

**Files:**
- Modify: `functions/package.json` (add `@google-cloud/kms` dependency)
- Create: `functions/src/services/kms.ts`
- Create: `functions/src/services/kms.test.ts`
- Create: `functions/src/encryptApiKey.ts`
- Create: `functions/src/encryptApiKey.test.ts`
- Modify: `functions/src/index.ts` (export `encryptApiKey`)

**Interfaces:**
- Produces: `encryptWithKms(plaintext: string): Promise<string>`, `decryptWithKms(ciphertextBase64: string): Promise<string>` (both from `./services/kms`) — used by Task 2. `encryptApiKey` onCall function — called by the web client in Task 3.

- [ ] **Step 1: Add the `@google-cloud/kms` dependency**

Modify `functions/package.json` — add to `dependencies`:

```json
  "dependencies": {
    "@google-cloud/kms": "^4.0.0",
    "firebase-admin": "^13.10.0",
    "firebase-functions": "7.3.2",
    "google-auth-library": "^10.9.1"
  },
```

Run: `npm --prefix functions install`

- [ ] **Step 2: Write the failing test for the KMS service module**

Create `functions/src/services/kms.test.ts`:

```ts
import { afterEach, describe, expect, it, vi } from "vitest";

const mockEncrypt = vi.fn();
const mockDecrypt = vi.fn();
const mockCryptoKeyPath = vi.fn(
  (project: string, location: string, keyRing: string, key: string) =>
    `projects/${project}/locations/${location}/keyRings/${keyRing}/cryptoKeys/${key}`
);

vi.mock("@google-cloud/kms", () => ({
  KeyManagementServiceClient: vi.fn().mockImplementation(() => ({
    encrypt: mockEncrypt,
    decrypt: mockDecrypt,
    cryptoKeyPath: mockCryptoKeyPath,
  })),
}));

afterEach(() => {
  vi.unstubAllEnvs();
  vi.clearAllMocks();
});

function stubKmsEnv() {
  vi.stubEnv("KMS_PROJECT_ID", "lexi-core");
  vi.stubEnv("KMS_LOCATION", "asia-southeast1");
  vi.stubEnv("KMS_KEY_RING", "lexicore-keys");
  vi.stubEnv("KMS_KEY_NAME", "byok-api-keys");
}

describe("encryptWithKms", () => {
  it("throws when KMS env vars are not configured", async () => {
    const { encryptWithKms } = await import("./kms");
    await expect(encryptWithKms("secret")).rejects.toThrow(/Cloud KMS configuration/);
  });

  it("encrypts plaintext via the correct key path and returns base64 ciphertext", async () => {
    stubKmsEnv();
    mockEncrypt.mockResolvedValue([{ ciphertext: Buffer.from("cipherbytes") }]);
    const { encryptWithKms } = await import("./kms");

    const result = await encryptWithKms("my-api-key");

    expect(mockCryptoKeyPath).toHaveBeenCalledWith(
      "lexi-core",
      "asia-southeast1",
      "lexicore-keys",
      "byok-api-keys"
    );
    expect(mockEncrypt).toHaveBeenCalledWith({
      name: "projects/lexi-core/locations/asia-southeast1/keyRings/lexicore-keys/cryptoKeys/byok-api-keys",
      plaintext: Buffer.from("my-api-key", "utf8"),
    });
    expect(result).toBe(Buffer.from("cipherbytes").toString("base64"));
  });

  it("throws when the KMS response has no ciphertext", async () => {
    stubKmsEnv();
    mockEncrypt.mockResolvedValue([{}]);
    const { encryptWithKms } = await import("./kms");
    await expect(encryptWithKms("my-api-key")).rejects.toThrow(/no ciphertext/);
  });
});

describe("decryptWithKms", () => {
  it("decrypts base64 ciphertext back to the original plaintext", async () => {
    stubKmsEnv();
    mockDecrypt.mockResolvedValue([{ plaintext: Buffer.from("my-api-key") }]);
    const { decryptWithKms } = await import("./kms");

    const result = await decryptWithKms(Buffer.from("cipherbytes").toString("base64"));

    expect(mockDecrypt).toHaveBeenCalledWith({
      name: "projects/lexi-core/locations/asia-southeast1/keyRings/lexicore-keys/cryptoKeys/byok-api-keys",
      ciphertext: Buffer.from("cipherbytes"),
    });
    expect(result).toBe("my-api-key");
  });

  it("throws when the KMS response has no plaintext", async () => {
    stubKmsEnv();
    mockDecrypt.mockResolvedValue([{}]);
    const { decryptWithKms } = await import("./kms");
    await expect(decryptWithKms("abc")).rejects.toThrow(/no plaintext/);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `npm --prefix functions test`
Expected: FAIL — `./kms` does not exist.

- [ ] **Step 4: Implement the KMS service module**

Create `functions/src/services/kms.ts`:

```ts
import { KeyManagementServiceClient } from "@google-cloud/kms";

let cachedClient: KeyManagementServiceClient | undefined;

function getClient(): KeyManagementServiceClient {
  return (cachedClient ??= new KeyManagementServiceClient());
}

function getKeyName(): string {
  const project = process.env.KMS_PROJECT_ID ?? "";
  const location = process.env.KMS_LOCATION ?? "";
  const keyRing = process.env.KMS_KEY_RING ?? "";
  const key = process.env.KMS_KEY_NAME ?? "";
  if (!project || !location || !keyRing || !key) {
    throw new Error(
      "Missing Cloud KMS configuration (KMS_PROJECT_ID/KMS_LOCATION/KMS_KEY_RING/KMS_KEY_NAME env vars)."
    );
  }
  return getClient().cryptoKeyPath(project, location, keyRing, key);
}

export async function encryptWithKms(plaintext: string): Promise<string> {
  const [result] = await getClient().encrypt({
    name: getKeyName(),
    plaintext: Buffer.from(plaintext, "utf8"),
  });
  if (!result.ciphertext) {
    throw new Error("Cloud KMS encrypt returned no ciphertext.");
  }
  return Buffer.from(result.ciphertext as Uint8Array).toString("base64");
}

export async function decryptWithKms(ciphertextBase64: string): Promise<string> {
  const [result] = await getClient().decrypt({
    name: getKeyName(),
    ciphertext: Buffer.from(ciphertextBase64, "base64"),
  });
  if (!result.plaintext) {
    throw new Error("Cloud KMS decrypt returned no plaintext.");
  }
  return Buffer.from(result.plaintext as Uint8Array).toString("utf8");
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix functions test`
Expected: PASS.

- [ ] **Step 6: Write the failing test for `encryptApiKey`**

Create `functions/src/encryptApiKey.test.ts`:

```ts
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
    expect(encryptWithKms).toHaveBeenCalledWith("sk-abc");
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
```

- [ ] **Step 7: Run test to verify it fails**

Run: `npm --prefix functions test`
Expected: FAIL — `./encryptApiKey` does not exist.

- [ ] **Step 8: Implement `encryptApiKey`**

Create `functions/src/encryptApiKey.ts`:

```ts
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { encryptWithKms } from "./services/kms";

export interface EncryptApiKeyRequest {
  apiKey: string;
}

export interface EncryptApiKeyResult {
  ciphertext: string;
}

function isEncryptApiKeyRequest(data: unknown): data is EncryptApiKeyRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return typeof d.apiKey === "string" && d.apiKey.trim().length > 0;
}

export async function encryptApiKeyHandler(
  request: CallableRequest<unknown>
): Promise<EncryptApiKeyResult> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isEncryptApiKeyRequest(request.data)) {
    throw new HttpsError("invalid-argument", "Expected { apiKey: string } (non-empty).");
  }

  try {
    const ciphertext = await encryptWithKms(request.data.apiKey);
    return { ciphertext };
  } catch {
    throw new HttpsError("internal", "Failed to encrypt API key. Please try again.");
  }
}

export const encryptApiKey = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 30 },
  encryptApiKeyHandler
);
```

- [ ] **Step 9: Export it from the functions index**

Modify `functions/src/index.ts`:

```ts
export { ping } from "./ping";
export { generateContent } from "./generateContent";
export { getPronunciation } from "./getPronunciation";
export { synthesizeSpeech } from "./synthesizeSpeech";
export { transcribeAudio } from "./transcribeAudio";
export { encryptApiKey } from "./encryptApiKey";
```

- [ ] **Step 10: Run tests and typecheck to verify everything passes**

Run: `npm --prefix functions test`
Expected: PASS.

Run: `npm --prefix functions run typecheck`
Expected: no errors.

- [ ] **Step 11: Commit**

```bash
git add functions/package.json functions/package-lock.json functions/src/services/kms.ts functions/src/services/kms.test.ts functions/src/encryptApiKey.ts functions/src/encryptApiKey.test.ts functions/src/index.ts
git commit -m "feat(functions): add Cloud KMS service and encryptApiKey onCall function"
```

---

## Task 2: `generateContent` ciphertext support

**Files:**
- Modify: `functions/src/generateContent.ts`
- Modify: `functions/src/generateContent.test.ts`
- Modify: `apps/web/src/lib/generateContent.ts` (keep the duplicated request type in sync)

**Interfaces:**
- Consumes: `decryptWithKms` from `./services/kms` (Task 1).
- Produces: `generateContent` now accepts `apiKeyCiphertext?: string` as an alternative to `apiKey?: string` — used by the Lookup/Practice-hub sub-spec (not built in this plan) once it reads a stored ciphertext from `users/{uid}/settings/config`.

- [ ] **Step 1: Write the failing tests for ciphertext support**

Modify `functions/src/generateContent.test.ts` — add `vi.mock` for the KMS service near the top (after the existing mocks) and new test cases inside the `describe("generateContentHandler", ...)` block:

```ts
vi.mock("./services/kms", () => ({ decryptWithKms: vi.fn() }));
```

(Add this line directly below the existing `vi.mock("./providers/openAiCompatible", ...)` block, and add `import { decryptWithKms } from "./services/kms";` alongside the other imports at the top of the file.)

Add these test cases at the end of the `describe("generateContentHandler", ...)` block, just before its closing `});`:

```ts
  it("throws invalid-argument when both apiKey and apiKeyCiphertext are provided", async () => {
    await expect(
      generateContentHandler(
        makeRequest({
          provider: "gemini",
          apiKey: "k",
          apiKeyCiphertext: "c",
          model: "gemini-2.5-flash",
          prompt: "hi",
        })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws invalid-argument when neither apiKey nor apiKeyCiphertext is provided", async () => {
    await expect(
      generateContentHandler(
        makeRequest({ provider: "gemini", model: "gemini-2.5-flash", prompt: "hi" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("decrypts apiKeyCiphertext via Cloud KMS and uses the result as the provider API key", async () => {
    vi.mocked(decryptWithKms).mockResolvedValue("decrypted-key");
    vi.mocked(callGemini).mockResolvedValue({ text: "hello" });

    const result = await generateContentHandler(
      makeRequest({
        provider: "gemini",
        apiKeyCiphertext: "cipher-abc",
        model: "gemini-2.5-flash",
        prompt: "hi",
      })
    );

    expect(decryptWithKms).toHaveBeenCalledWith("cipher-abc");
    expect(callGemini).toHaveBeenCalledWith({
      apiKey: "decrypted-key",
      model: "gemini-2.5-flash",
      prompt: "hi",
    });
    expect(result).toEqual({ text: "hello" });
  });

  it("wraps a KMS decrypt failure in an internal HttpsError without leaking details, and never calls the provider", async () => {
    vi.mocked(decryptWithKms).mockRejectedValue(new Error("KMS key not found: projects/..."));
    // callGemini's mock call history accumulates across this file's other
    // tests (no clearMocks/afterEach here) — compare a before/after count
    // instead of asserting not.toHaveBeenCalled(), which would spuriously
    // fail because of earlier tests' calls.
    const callsBefore = vi.mocked(callGemini).mock.calls.length;
    let caught: unknown;
    try {
      await generateContentHandler(
        makeRequest({
          provider: "gemini",
          apiKeyCiphertext: "cipher-abc",
          model: "gemini-2.5-flash",
          prompt: "hi",
        })
      );
    } catch (err) {
      caught = err;
    }
    expect(caught).toMatchObject({
      code: "internal",
      message: "Failed to decrypt API key. Please try again.",
    });
    expect(vi.mocked(callGemini).mock.calls.length).toBe(callsBefore);
  });
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `npm --prefix functions test`
Expected: FAIL — current validation only accepts `apiKey`, and `decryptWithKms` is not wired up yet.

- [ ] **Step 3: Implement ciphertext support**

Replace `functions/src/generateContent.ts`:

```ts
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { callGemini } from "./providers/gemini";
import { callGroq, callOpenRouter } from "./providers/openAiCompatible";
import { decryptWithKms } from "./services/kms";
import { ProviderApiError, type GenerateContentResult } from "./providers/types";

// Keep this in sync with the client-side type of the same name in
// apps/web/src/lib/generateContent.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export type AiProvider = "gemini" | "groq" | "openrouter";

// Keep this in sync with the client-side type of the same name in
// apps/web/src/lib/generateContent.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
//
// Exactly one of apiKey/apiKeyCiphertext must be set: apiKey is the raw BYOK
// key (original React Web Plan 1 behavior); apiKeyCiphertext is a Cloud
// KMS ciphertext (base64) produced by encryptApiKey and read back from
// users/{uid}/settings/config — added in React Web Plan 3 Phase B.
export interface GenerateContentRequest {
  provider: AiProvider;
  apiKey?: string;
  apiKeyCiphertext?: string;
  model: string;
  prompt: string;
}

function isGenerateContentRequest(data: unknown): data is GenerateContentRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  const hasRawKey = typeof d.apiKey === "string" && d.apiKey.length > 0;
  const hasCiphertext = typeof d.apiKeyCiphertext === "string" && d.apiKeyCiphertext.length > 0;
  return (
    (d.provider === "gemini" || d.provider === "groq" || d.provider === "openrouter") &&
    hasRawKey !== hasCiphertext &&
    typeof d.model === "string" &&
    d.model.length > 0 &&
    typeof d.prompt === "string" &&
    d.prompt.length > 0
  );
}

export async function generateContentHandler(
  request: CallableRequest<unknown>
): Promise<GenerateContentResult> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isGenerateContentRequest(request.data)) {
    throw new HttpsError(
      "invalid-argument",
      "Expected { provider, model, prompt, and exactly one of apiKey/apiKeyCiphertext }."
    );
  }

  const { provider, model, prompt, apiKeyCiphertext } = request.data;

  let apiKey: string;
  if (apiKeyCiphertext) {
    try {
      apiKey = await decryptWithKms(apiKeyCiphertext);
    } catch {
      throw new HttpsError("internal", "Failed to decrypt API key. Please try again.");
    }
  } else {
    apiKey = request.data.apiKey as string;
  }

  const params = { apiKey, model, prompt };

  try {
    switch (provider) {
      case "gemini":
        return await callGemini(params);
      case "groq":
        return await callGroq(params);
      case "openrouter":
        return await callOpenRouter(params);
      default: {
        const exhaustiveCheck: never = provider;
        throw new HttpsError("invalid-argument", `Unknown provider: ${exhaustiveCheck}`);
      }
    }
  } catch (err) {
    if (err instanceof HttpsError) {
      throw err;
    }
    logger.error(`AI provider call failed (provider: ${provider})`, {
      provider,
      error: err instanceof Error ? err.message : String(err),
    });

    if (err instanceof ProviderApiError) {
      const status = err.status;
      if (status === 401 || status === 403) {
        throw new HttpsError(
          "permission-denied",
          "Provider rejected the API key. Check it's correct and active."
        );
      }
      if (status === 429) {
        throw new HttpsError(
          "resource-exhausted",
          "Provider rate limit or quota exceeded. Try again shortly."
        );
      }
      if (status !== undefined && status >= 500 && status <= 599) {
        throw new HttpsError(
          "unavailable",
          "Provider is temporarily unavailable. Try again in a moment."
        );
      }
    }

    throw new HttpsError("internal", "AI provider call failed. Please try again.");
  }
}

export const generateContent = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 120 },
  generateContentHandler
);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm --prefix functions test`
Expected: PASS — including the existing tests (they still pass a raw `apiKey`, unaffected).

- [ ] **Step 5: Keep the client-side duplicated type in sync**

Modify `apps/web/src/lib/generateContent.ts`:

```ts
import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";

// Keep this in sync with the server-side type of the same name in
// functions/src/generateContent.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export type AiProvider = "gemini" | "groq" | "openrouter";

// Keep this in sync with the server-side type of the same name in
// functions/src/generateContent.ts. Exactly one of apiKey/apiKeyCiphertext
// must be set — see that file's comment for details.
export interface GenerateContentRequest {
  provider: AiProvider;
  apiKey?: string;
  apiKeyCiphertext?: string;
  model: string;
  prompt: string;
}

// Keep this in sync with the server-side type of the same name in
// functions/src/providers/types.ts (no shared-types package yet — see
// docs/superpowers/plans/2026-08-11-web-backend-infra-core.md Task 6/7).
export interface GenerateContentResult {
  text: string;
}

export async function generateContent(
  request: GenerateContentRequest
): Promise<GenerateContentResult> {
  const callable = httpsCallable<GenerateContentRequest, GenerateContentResult>(
    getFirebaseFunctions(),
    "generateContent"
  );
  const response = await callable(request);
  return response.data;
}
```

- [ ] **Step 6: Run the web suite to confirm nothing broke**

Run: `npm --prefix apps/web test`
Expected: PASS — `GenerateContentPanel.test.tsx` still passes `apiKey` only, which remains valid since the field is now optional but still accepted.

- [ ] **Step 7: Commit**

```bash
git add functions/src/generateContent.ts functions/src/generateContent.test.ts apps/web/src/lib/generateContent.ts
git commit -m "feat(functions): accept a Cloud KMS ciphertext as an alternative to a raw API key in generateContent"
```

---

## Task 3: `apps/web` settings data layer

**Files:**
- Create: `apps/web/src/lib/modelPresets.ts`
- Create: `apps/web/src/lib/modelPresets.test.ts`
- Create: `apps/web/src/lib/settings.ts`
- Create: `apps/web/src/lib/settings.test.ts`
- Create: `apps/web/src/lib/useSettings.ts`
- Create: `apps/web/src/lib/useSettings.test.ts`
- Create: `apps/web/src/lib/encryptApiKey.ts`
- Create: `apps/web/src/lib/encryptApiKey.test.ts`

**Interfaces:**
- Produces: `AiProvider`, `MODEL_PRESETS`, `PROVIDER_LABELS` (`@/lib/modelPresets`); `UserSettings`, `ProviderSettings`, `Theme`, `FontSize`, `DEFAULT_SETTINGS`, `getSettings(uid)`, `saveSettings(uid, settings)` (`@/lib/settings`); `useSettings(uid: string | null): { settings: UserSettings | null; loading: boolean; error: string | null; save: (next: UserSettings) => Promise<void> }` (`@/lib/useSettings`); `encryptApiKey(request: { apiKey: string }): Promise<{ ciphertext: string }>` (`@/lib/encryptApiKey`). Used by Tasks 4-8.

- [ ] **Step 1: Write the failing test for model presets**

Create `apps/web/src/lib/modelPresets.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { MODEL_PRESETS, PROVIDER_LABELS } from "./modelPresets";

describe("MODEL_PRESETS", () => {
  it("defines the exact Gemini presets and default, matching the Flutter app's AiProvider", () => {
    expect(MODEL_PRESETS.gemini.defaultModel).toBe("gemini-2.5-flash");
    expect(MODEL_PRESETS.gemini.presets).toEqual([
      "gemini-2.5-flash",
      "gemini-2.5-pro",
      "gemini-2.0-flash",
      "gemini-1.5-flash",
    ]);
  });

  it("defines the exact Groq presets and default", () => {
    expect(MODEL_PRESETS.groq.defaultModel).toBe("llama-3.3-70b-versatile");
    expect(MODEL_PRESETS.groq.presets).toEqual([
      "llama-3.3-70b-versatile",
      "llama-3.1-8b-instant",
      "mixtral-8x7b-32768",
      "gemma2-9b-it",
    ]);
  });

  it("defines the exact OpenRouter presets and default", () => {
    expect(MODEL_PRESETS.openrouter.defaultModel).toBe("meta-llama/llama-3.3-70b-instruct");
    expect(MODEL_PRESETS.openrouter.presets).toEqual([
      "meta-llama/llama-3.3-70b-instruct",
      "google/gemini-2.5-flash",
      "anthropic/claude-haiku-4-5",
      "mistralai/mixtral-8x7b-instruct",
    ]);
  });
});

describe("PROVIDER_LABELS", () => {
  it("has a Vietnamese-safe display label for every provider", () => {
    expect(PROVIDER_LABELS).toEqual({
      gemini: "Gemini",
      groq: "Groq",
      openrouter: "OpenRouter",
    });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./modelPresets` does not exist.

- [ ] **Step 3: Implement model presets**

Create `apps/web/src/lib/modelPresets.ts`:

```ts
export type AiProvider = "gemini" | "groq" | "openrouter";

export interface ProviderModelInfo {
  defaultModel: string;
  presets: string[];
}

// Mirrors lib/features/dictionary/domain/entities/ai_provider.dart's
// AiProviderX.defaultModel/modelPresets — kept in sync manually (no
// shared-types package between the Flutter and web apps).
export const MODEL_PRESETS: Record<AiProvider, ProviderModelInfo> = {
  gemini: {
    defaultModel: "gemini-2.5-flash",
    presets: ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash", "gemini-1.5-flash"],
  },
  groq: {
    defaultModel: "llama-3.3-70b-versatile",
    presets: [
      "llama-3.3-70b-versatile",
      "llama-3.1-8b-instant",
      "mixtral-8x7b-32768",
      "gemma2-9b-it",
    ],
  },
  openrouter: {
    defaultModel: "meta-llama/llama-3.3-70b-instruct",
    presets: [
      "meta-llama/llama-3.3-70b-instruct",
      "google/gemini-2.5-flash",
      "anthropic/claude-haiku-4-5",
      "mistralai/mixtral-8x7b-instruct",
    ],
  },
};

export const PROVIDER_LABELS: Record<AiProvider, string> = {
  gemini: "Gemini",
  groq: "Groq",
  openrouter: "OpenRouter",
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Write the failing test for the settings data layer**

Create `apps/web/src/lib/settings.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { DEFAULT_SETTINGS, getSettings, saveSettings, type UserSettings } from "./settings";

vi.mock("firebase/firestore", () => ({
  doc: vi.fn(() => "mock-doc-ref"),
  getDoc: vi.fn(),
  setDoc: vi.fn(),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

describe("DEFAULT_SETTINGS", () => {
  it("defaults to Gemini active, system theme, medium font size, no keys saved", () => {
    expect(DEFAULT_SETTINGS.activeProvider).toBe("gemini");
    expect(DEFAULT_SETTINGS.theme).toBe("system");
    expect(DEFAULT_SETTINGS.fontSize).toBe("medium");
    expect(DEFAULT_SETTINGS.providers.gemini.apiKeyCiphertext).toBeNull();
    expect(DEFAULT_SETTINGS.providers.groq.apiKeyCiphertext).toBeNull();
    expect(DEFAULT_SETTINGS.providers.openrouter.apiKeyCiphertext).toBeNull();
  });
});

describe("getSettings", () => {
  it("returns DEFAULT_SETTINGS when the doc does not exist", async () => {
    vi.mocked(getDoc).mockResolvedValue({ exists: () => false } as never);
    const result = await getSettings("user-123");
    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "settings", "config");
    expect(result).toEqual(DEFAULT_SETTINGS);
  });

  it("merges the stored doc over the defaults when it exists", async () => {
    const stored: Partial<UserSettings> = {
      activeProvider: "groq",
      theme: "dark",
    };
    vi.mocked(getDoc).mockResolvedValue({
      exists: () => true,
      data: () => stored,
    } as never);

    const result = await getSettings("user-123");

    expect(result.activeProvider).toBe("groq");
    expect(result.theme).toBe("dark");
    expect(result.fontSize).toBe("medium");
    expect(result.providers).toEqual(DEFAULT_SETTINGS.providers);
  });
});

describe("saveSettings", () => {
  it("writes the full settings object to the user's settings/config doc", async () => {
    const settings: UserSettings = {
      ...DEFAULT_SETTINGS,
      activeProvider: "openrouter",
    };
    await saveSettings("user-123", settings);
    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "settings", "config");
    expect(setDoc).toHaveBeenCalledWith("mock-doc-ref", settings);
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./settings` does not exist.

- [ ] **Step 7: Implement the settings data layer**

Create `apps/web/src/lib/settings.ts`:

```ts
import { doc, getDoc, setDoc } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import { MODEL_PRESETS, type AiProvider } from "./modelPresets";

export interface ProviderSettings {
  model: string;
  apiKeyCiphertext: string | null;
}

export type Theme = "light" | "dark" | "system";
export type FontSize = "small" | "medium" | "large";

export interface UserSettings {
  activeProvider: AiProvider;
  providers: Record<AiProvider, ProviderSettings>;
  theme: Theme;
  fontSize: FontSize;
}

export const DEFAULT_SETTINGS: UserSettings = {
  activeProvider: "gemini",
  providers: {
    gemini: { model: MODEL_PRESETS.gemini.defaultModel, apiKeyCiphertext: null },
    groq: { model: MODEL_PRESETS.groq.defaultModel, apiKeyCiphertext: null },
    openrouter: { model: MODEL_PRESETS.openrouter.defaultModel, apiKeyCiphertext: null },
  },
  theme: "system",
  fontSize: "medium",
};

function settingsRef(uid: string) {
  return doc(getFirebaseDb(), "users", uid, "settings", "config");
}

export async function getSettings(uid: string): Promise<UserSettings> {
  const snap = await getDoc(settingsRef(uid));
  if (!snap.exists()) {
    return DEFAULT_SETTINGS;
  }
  const stored = snap.data() as Partial<UserSettings>;
  return {
    ...DEFAULT_SETTINGS,
    ...stored,
    providers: { ...DEFAULT_SETTINGS.providers, ...stored.providers },
  };
}

export async function saveSettings(uid: string, settings: UserSettings): Promise<void> {
  await setDoc(settingsRef(uid), settings);
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 9: Write the failing test for the `useSettings` hook**

Create `apps/web/src/lib/useSettings.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { renderHook, waitFor, act } from "@testing-library/react";
import { useSettings } from "./useSettings";
import { getSettings, saveSettings, DEFAULT_SETTINGS } from "./settings";

vi.mock("./settings", async () => {
  const actual = await vi.importActual<typeof import("./settings")>("./settings");
  return {
    ...actual,
    getSettings: vi.fn(),
    saveSettings: vi.fn(),
  };
});

describe("useSettings", () => {
  it("returns DEFAULT_SETTINGS immediately with loading=false when uid is null (logged out)", async () => {
    const { result } = renderHook(() => useSettings(null));
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.settings).toEqual(DEFAULT_SETTINGS);
    expect(getSettings).not.toHaveBeenCalled();
  });

  it("loads settings for a real uid", async () => {
    const loaded = { ...DEFAULT_SETTINGS, theme: "dark" as const };
    vi.mocked(getSettings).mockResolvedValue(loaded);

    const { result } = renderHook(() => useSettings("user-123"));

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(getSettings).toHaveBeenCalledWith("user-123");
    expect(result.current.settings).toEqual(loaded);
    expect(result.current.error).toBeNull();
  });

  it("sets error when getSettings rejects", async () => {
    vi.mocked(getSettings).mockRejectedValue(new Error("offline"));
    const { result } = renderHook(() => useSettings("user-123"));
    await waitFor(() => expect(result.current.error).toBe("offline"));
  });

  it("save() persists via saveSettings and updates local state once the write succeeds", async () => {
    vi.mocked(getSettings).mockResolvedValue(DEFAULT_SETTINGS);
    vi.mocked(saveSettings).mockResolvedValue(undefined);
    const { result } = renderHook(() => useSettings("user-123"));
    await waitFor(() => expect(result.current.loading).toBe(false));

    const next = { ...DEFAULT_SETTINGS, theme: "dark" as const };
    await act(async () => {
      await result.current.save(next);
    });

    expect(saveSettings).toHaveBeenCalledWith("user-123", next);
    expect(result.current.settings).toEqual(next);
  });
});
```

- [ ] **Step 10: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./useSettings` does not exist.

- [ ] **Step 11: Implement `useSettings`**

Create `apps/web/src/lib/useSettings.ts`:

```ts
"use client";

import { useCallback, useEffect, useState } from "react";
import { DEFAULT_SETTINGS, getSettings, saveSettings, type UserSettings } from "./settings";

export function useSettings(uid: string | null) {
  const [settings, setSettings] = useState<UserSettings | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!uid) {
      setSettings(DEFAULT_SETTINGS);
      setError(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    getSettings(uid)
      .then((s) => setSettings(s))
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)))
      .finally(() => setLoading(false));
  }, [uid]);

  const save = useCallback(
    async (next: UserSettings) => {
      if (!uid) return;
      await saveSettings(uid, next);
      setSettings(next);
    },
    [uid]
  );

  return { settings, loading, error, save };
}
```

- [ ] **Step 12: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 13: Write the failing test for the `encryptApiKey` client wrapper**

Create `apps/web/src/lib/encryptApiKey.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { httpsCallable } from "firebase/functions";
import { encryptApiKey } from "./encryptApiKey";

const mockCallable = vi.fn();

vi.mock("firebase/functions", () => ({
  httpsCallable: vi.fn(() => mockCallable),
}));

vi.mock("./firebase", () => ({
  getFirebaseFunctions: vi.fn(() => "mock-functions"),
}));

describe("encryptApiKey", () => {
  it("calls the encryptApiKey callable with the request and returns its data", async () => {
    mockCallable.mockResolvedValue({ data: { ciphertext: "cipher-abc" } });

    const result = await encryptApiKey({ apiKey: "sk-real-key" });

    expect(httpsCallable).toHaveBeenCalledWith("mock-functions", "encryptApiKey");
    expect(mockCallable).toHaveBeenCalledWith({ apiKey: "sk-real-key" });
    expect(result).toEqual({ ciphertext: "cipher-abc" });
  });
});
```

- [ ] **Step 14: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./encryptApiKey` does not exist.

- [ ] **Step 15: Implement the `encryptApiKey` client wrapper**

Create `apps/web/src/lib/encryptApiKey.ts`:

```ts
import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";

// Keep this in sync with the server-side type of the same name in
// functions/src/encryptApiKey.ts.
export interface EncryptApiKeyRequest {
  apiKey: string;
}

export interface EncryptApiKeyResult {
  ciphertext: string;
}

export async function encryptApiKey(
  request: EncryptApiKeyRequest
): Promise<EncryptApiKeyResult> {
  const callable = httpsCallable<EncryptApiKeyRequest, EncryptApiKeyResult>(
    getFirebaseFunctions(),
    "encryptApiKey"
  );
  const response = await callable(request);
  return response.data;
}
```

- [ ] **Step 16: Run the full suite to verify everything passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 17: Commit**

```bash
git add apps/web/src/lib/modelPresets.ts apps/web/src/lib/modelPresets.test.ts apps/web/src/lib/settings.ts apps/web/src/lib/settings.test.ts apps/web/src/lib/useSettings.ts apps/web/src/lib/useSettings.test.ts apps/web/src/lib/encryptApiKey.ts apps/web/src/lib/encryptApiKey.test.ts
git commit -m "feat(web): add Settings data layer (model presets, Firestore CRUD, useSettings hook, encryptApiKey client)"
```

---

## Task 4: `ModelPicker` component

**Files:**
- Create: `apps/web/src/components/settings/ModelPicker.tsx`
- Create: `apps/web/src/components/settings/ModelPicker.test.tsx`

**Interfaces:**
- Consumes: `MODEL_PRESETS`, `AiProvider` (`@/lib/modelPresets`, Task 3).
- Produces: `<ModelPicker provider model onChange />` — used by Task 5.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/components/settings/ModelPicker.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { ModelPicker } from "./ModelPicker";

describe("ModelPicker", () => {
  it("renders all presets for the given provider plus a 'Khác...' option", () => {
    render(<ModelPicker provider="gemini" model="gemini-2.5-flash" onChange={vi.fn()} />);
    expect(screen.getByRole("option", { name: "gemini-2.5-pro" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "gemini-1.5-flash" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "Khác..." })).toBeInTheDocument();
  });

  it("calls onChange when a different preset is selected", () => {
    const onChange = vi.fn();
    render(<ModelPicker provider="gemini" model="gemini-2.5-flash" onChange={onChange} />);
    fireEvent.change(screen.getByLabelText("Model"), {
      target: { value: "gemini-2.5-pro" },
    });
    expect(onChange).toHaveBeenCalledWith("gemini-2.5-pro");
  });

  it("shows a custom text input immediately when the current model is not a preset", () => {
    render(<ModelPicker provider="gemini" model="gemini-3.0-experimental" onChange={vi.fn()} />);
    expect(screen.getByLabelText("Tên model tuỳ chỉnh")).toHaveValue("gemini-3.0-experimental");
  });

  it("reveals the custom input after selecting 'Khác...', and calls onChange on blur with the typed value", () => {
    const onChange = vi.fn();
    render(<ModelPicker provider="groq" model="llama-3.3-70b-versatile" onChange={onChange} />);

    fireEvent.change(screen.getByLabelText("Model"), {
      target: { value: "__custom__" },
    });
    const input = screen.getByLabelText("Tên model tuỳ chỉnh");
    fireEvent.change(input, { target: { value: "llama-4-new-model" } });
    fireEvent.blur(input);

    expect(onChange).toHaveBeenCalledWith("llama-4-new-model");
  });

  it("does not call onChange on blur when the custom input is empty", () => {
    const onChange = vi.fn();
    render(<ModelPicker provider="groq" model="not-a-preset" onChange={onChange} />);
    const input = screen.getByLabelText("Tên model tuỳ chỉnh");
    fireEvent.change(input, { target: { value: "  " } });
    fireEvent.blur(input);
    expect(onChange).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./ModelPicker` does not exist.

- [ ] **Step 3: Implement `ModelPicker`**

Create `apps/web/src/components/settings/ModelPicker.tsx`:

```tsx
"use client";

import { useState } from "react";
import { MODEL_PRESETS, type AiProvider } from "@/lib/modelPresets";

const CUSTOM_VALUE = "__custom__";

interface ModelPickerProps {
  provider: AiProvider;
  model: string;
  onChange: (model: string) => void;
}

export function ModelPicker({ provider, model, onChange }: ModelPickerProps) {
  const { presets } = MODEL_PRESETS[provider];
  const modelIsPreset = presets.includes(model);
  // `customMode` tracks the user's dropdown choice locally: selecting
  // "Khác..." must reveal the free-text input immediately, before onChange
  // has fired and before the `model` prop has changed — isCustom can't be
  // derived from `model` alone, or the input would never appear (selecting
  // "Khác..." wouldn't change `model`, so a props-only isCustom would stay
  // false and the input required to fix that would never render).
  const [customMode, setCustomMode] = useState(!modelIsPreset);
  const [customDraft, setCustomDraft] = useState(model);

  const showCustomInput = customMode || !modelIsPreset;

  return (
    <div>
      <label>
        Model
        <select
          value={showCustomInput ? CUSTOM_VALUE : model}
          onChange={(e) => {
            if (e.target.value === CUSTOM_VALUE) {
              setCustomMode(true);
              setCustomDraft(modelIsPreset ? "" : model);
            } else {
              setCustomMode(false);
              onChange(e.target.value);
            }
          }}
        >
          {presets.map((m) => (
            <option key={m} value={m}>
              {m}
            </option>
          ))}
          <option value={CUSTOM_VALUE}>Khác...</option>
        </select>
      </label>
      {showCustomInput && (
        <input
          aria-label="Tên model tuỳ chỉnh"
          value={customDraft}
          onChange={(e) => setCustomDraft(e.target.value)}
          onBlur={() => {
            if (customDraft.trim()) onChange(customDraft.trim());
          }}
        />
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/settings/ModelPicker.tsx apps/web/src/components/settings/ModelPicker.test.tsx
git commit -m "feat(web): add ModelPicker component (preset dropdown + free-text custom model)"
```

---

## Task 5: `AiProviderSection` component

**Files:**
- Create: `apps/web/src/components/settings/AiProviderSection.tsx`
- Create: `apps/web/src/components/settings/AiProviderSection.test.tsx`

**Interfaces:**
- Consumes: `UserSettings` (`@/lib/settings`, Task 3), `encryptApiKey` (`@/lib/encryptApiKey`, Task 3), `PROVIDER_LABELS`/`AiProvider` (`@/lib/modelPresets`, Task 3), `<ModelPicker />` (Task 4).
- Produces: `<AiProviderSection settings onSave />` — used by Task 8.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/components/settings/AiProviderSection.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { AiProviderSection } from "./AiProviderSection";
import { encryptApiKey } from "@/lib/encryptApiKey";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/encryptApiKey", () => ({ encryptApiKey: vi.fn() }));

describe("AiProviderSection", () => {
  it("renders all 3 providers and calls onSave with the new activeProvider when switching", () => {
    const onSave = vi.fn();
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={onSave} />);

    expect(screen.getByRole("option", { name: "Gemini" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "Groq" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "OpenRouter" })).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Provider"), { target: { value: "groq" } });

    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, activeProvider: "groq" });
  });

  it("propagates a model change through onSave for the active provider only", () => {
    const onSave = vi.fn();
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={onSave} />);

    fireEvent.change(screen.getByLabelText("Model"), { target: { value: "gemini-2.5-pro" } });

    expect(onSave).toHaveBeenCalledWith({
      ...DEFAULT_SETTINGS,
      providers: {
        ...DEFAULT_SETTINGS.providers,
        gemini: { ...DEFAULT_SETTINGS.providers.gemini, model: "gemini-2.5-pro" },
      },
    });
  });

  it("shows a masked placeholder when a key is already saved for the active provider", () => {
    const settings = {
      ...DEFAULT_SETTINGS,
      providers: {
        ...DEFAULT_SETTINGS.providers,
        gemini: { ...DEFAULT_SETTINGS.providers.gemini, apiKeyCiphertext: "existing-cipher" },
      },
    };
    render(<AiProviderSection settings={settings} onSave={vi.fn()} />);
    expect(screen.getByLabelText("API key")).toHaveAttribute("placeholder", "••••••••");
  });

  it("encrypts and saves a new key when Cập nhật is clicked", async () => {
    vi.mocked(encryptApiKey).mockResolvedValue({ ciphertext: "new-cipher" });
    const onSave = vi.fn();
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={onSave} />);

    fireEvent.change(screen.getByLabelText("API key"), { target: { value: "sk-new-key" } });
    fireEvent.click(screen.getByRole("button", { name: "Cập nhật" }));

    await waitFor(() =>
      expect(onSave).toHaveBeenCalledWith({
        ...DEFAULT_SETTINGS,
        providers: {
          ...DEFAULT_SETTINGS.providers,
          gemini: { ...DEFAULT_SETTINGS.providers.gemini, apiKeyCiphertext: "new-cipher" },
        },
      })
    );
    expect(encryptApiKey).toHaveBeenCalledWith({ apiKey: "sk-new-key" });
    expect(screen.getByLabelText("API key")).toHaveValue("");
  });

  it("shows an alert and does not call onSave when encryptApiKey fails", async () => {
    vi.mocked(encryptApiKey).mockRejectedValue(new Error("unauthenticated"));
    const onSave = vi.fn();
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={onSave} />);

    fireEvent.change(screen.getByLabelText("API key"), { target: { value: "sk-new-key" } });
    fireEvent.click(screen.getByRole("button", { name: "Cập nhật" }));

    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("unauthenticated"));
    expect(onSave).not.toHaveBeenCalled();
  });

  it("disables Cập nhật while the API key input is empty", () => {
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={vi.fn()} />);
    expect(screen.getByRole("button", { name: "Cập nhật" })).toBeDisabled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./AiProviderSection` does not exist.

- [ ] **Step 3: Implement `AiProviderSection`**

Create `apps/web/src/components/settings/AiProviderSection.tsx`:

```tsx
"use client";

import { useState } from "react";
import { ModelPicker } from "./ModelPicker";
import { encryptApiKey } from "@/lib/encryptApiKey";
import { PROVIDER_LABELS, type AiProvider } from "@/lib/modelPresets";
import type { UserSettings } from "@/lib/settings";

interface AiProviderSectionProps {
  settings: UserSettings;
  onSave: (next: UserSettings) => void | Promise<void>;
}

const PROVIDERS: AiProvider[] = ["gemini", "groq", "openrouter"];

export function AiProviderSection({ settings, onSave }: AiProviderSectionProps) {
  const [keyDraft, setKeyDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const active = settings.activeProvider;
  const activeConfig = settings.providers[active];

  async function handleUpdateKey() {
    const trimmed = keyDraft.trim();
    if (!trimmed) return;
    setSaving(true);
    setError(null);
    try {
      const { ciphertext } = await encryptApiKey({ apiKey: trimmed });
      await onSave({
        ...settings,
        providers: {
          ...settings.providers,
          [active]: { ...activeConfig, apiKeyCiphertext: ciphertext },
        },
      });
      setKeyDraft("");
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <section>
      <h3 className="scr-title">AI Provider &amp; API Key</h3>
      <label>
        Provider
        <select
          value={active}
          onChange={(e) =>
            void onSave({ ...settings, activeProvider: e.target.value as AiProvider })
          }
        >
          {PROVIDERS.map((p) => (
            <option key={p} value={p}>
              {PROVIDER_LABELS[p]}
            </option>
          ))}
        </select>
      </label>
      <ModelPicker
        provider={active}
        model={activeConfig.model}
        onChange={(model) =>
          void onSave({
            ...settings,
            providers: { ...settings.providers, [active]: { ...activeConfig, model } },
          })
        }
      />
      <label>
        API key
        <input
          type="password"
          value={keyDraft}
          placeholder={activeConfig.apiKeyCiphertext ? "••••••••" : ""}
          onChange={(e) => setKeyDraft(e.target.value)}
        />
      </label>
      <button onClick={() => void handleUpdateKey()} disabled={saving || !keyDraft.trim()}>
        Cập nhật
      </button>
      {error && <p role="alert">{error}</p>}
    </section>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/settings/AiProviderSection.tsx apps/web/src/components/settings/AiProviderSection.test.tsx
git commit -m "feat(web): add AiProviderSection (provider/model/API key UI)"
```

---

## Task 6: Giao diện (theme + font-size) — `AppearanceSection` + `AppShell` wiring

**Files:**
- Create: `apps/web/src/components/settings/AppearanceSection.tsx`
- Create: `apps/web/src/components/settings/AppearanceSection.test.tsx`
- Modify: `apps/web/src/components/shell/AppShell.tsx`
- Modify: `apps/web/src/components/shell/AppShell.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append font-size classes)

**Interfaces:**
- Consumes: `UserSettings`, `Theme`, `FontSize` (`@/lib/settings`, Task 3), `useAuthUser` (`@/lib/useAuthUser`), `useSettings` (`@/lib/useSettings`, Task 3).
- Produces: `<AppearanceSection settings onSave />` — used by Task 8. `AppShell` now applies the signed-in user's theme/font-size globally to every screen.

- [ ] **Step 1: Write the failing test for `AppearanceSection`**

Create `apps/web/src/components/settings/AppearanceSection.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { AppearanceSection } from "./AppearanceSection";
import { DEFAULT_SETTINGS } from "@/lib/settings";

describe("AppearanceSection", () => {
  it("renders the current theme and font size", () => {
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={vi.fn()} />);
    expect(screen.getByLabelText("Chủ đề")).toHaveValue("system");
    expect(screen.getByLabelText("Cỡ chữ")).toHaveValue("medium");
  });

  it("calls onSave with the new theme when changed", () => {
    const onSave = vi.fn();
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.change(screen.getByLabelText("Chủ đề"), { target: { value: "dark" } });
    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, theme: "dark" });
  });

  it("calls onSave with the new font size when changed", () => {
    const onSave = vi.fn();
    render(<AppearanceSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.change(screen.getByLabelText("Cỡ chữ"), { target: { value: "large" } });
    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, fontSize: "large" });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./AppearanceSection` does not exist.

- [ ] **Step 3: Implement `AppearanceSection`**

Create `apps/web/src/components/settings/AppearanceSection.tsx`:

```tsx
"use client";

import type { FontSize, Theme, UserSettings } from "@/lib/settings";

interface AppearanceSectionProps {
  settings: UserSettings;
  onSave: (next: UserSettings) => void | Promise<void>;
}

const THEMES: Theme[] = ["light", "dark", "system"];
const THEME_LABELS: Record<Theme, string> = {
  light: "Sáng",
  dark: "Tối",
  system: "Theo hệ thống",
};

const FONT_SIZES: FontSize[] = ["small", "medium", "large"];
const FONT_SIZE_LABELS: Record<FontSize, string> = {
  small: "Nhỏ",
  medium: "Vừa",
  large: "Lớn",
};

export function AppearanceSection({ settings, onSave }: AppearanceSectionProps) {
  return (
    <section>
      <h3 className="scr-title">Giao diện</h3>
      <label>
        Chủ đề
        <select
          value={settings.theme}
          onChange={(e) => void onSave({ ...settings, theme: e.target.value as Theme })}
        >
          {THEMES.map((t) => (
            <option key={t} value={t}>
              {THEME_LABELS[t]}
            </option>
          ))}
        </select>
      </label>
      <label>
        Cỡ chữ
        <select
          value={settings.fontSize}
          onChange={(e) => void onSave({ ...settings, fontSize: e.target.value as FontSize })}
        >
          {FONT_SIZES.map((f) => (
            <option key={f} value={f}>
              {FONT_SIZE_LABELS[f]}
            </option>
          ))}
        </select>
      </label>
    </section>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Write the failing test for `AppShell`'s theme/font-size wiring**

Replace `apps/web/src/components/shell/AppShell.test.tsx`:

```tsx
import { afterEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { AppShell } from "./AppShell";
import { usePathname } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettings } from "@/lib/useSettings";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("next/navigation", () => ({
  usePathname: vi.fn(() => "/vocab-bank"),
}));
vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/useSettings", () => ({ useSettings: vi.fn() }));

afterEach(() => {
  document.documentElement.removeAttribute("data-theme");
});

describe("AppShell", () => {
  it("renders the sidebar brand and the children inside the main content area", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>Screen content</p>
      </AppShell>
    );
    expect(screen.getByText("LexiCore")).toBeInTheDocument();
    const main = screen.getByText("Screen content").closest("main");
    expect(main).toHaveClass("main");
  });

  it("sets data-theme='dark' on <html> when the loaded settings say theme is dark", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: { ...DEFAULT_SETTINGS, theme: "dark" },
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>content</p>
      </AppShell>
    );

    await waitFor(() =>
      expect(document.documentElement.getAttribute("data-theme")).toBe("dark")
    );
  });

  it("removes data-theme from <html> when theme is 'system'", async () => {
    document.documentElement.setAttribute("data-theme", "dark");
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: { ...DEFAULT_SETTINGS, theme: "system" },
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>content</p>
      </AppShell>
    );

    await waitFor(() =>
      expect(document.documentElement.hasAttribute("data-theme")).toBe(false)
    );
  });

  it("applies the fs-large class to .app-frame when font size is large", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: { ...DEFAULT_SETTINGS, fontSize: "large" },
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>content</p>
      </AppShell>
    );

    expect(screen.getByText("content").closest(".app-frame")).toHaveClass("fs-large");
  });

  it("applies no font-size class for the medium (default) size", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(
      <AppShell>
        <p>content</p>
      </AppShell>
    );

    const frame = screen.getByText("content").closest(".app-frame");
    expect(frame).not.toHaveClass("fs-small");
    expect(frame).not.toHaveClass("fs-large");
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `AppShell` doesn't call `useAuthUser`/`useSettings` yet, doesn't touch `data-theme`, doesn't add a font-size class.

- [ ] **Step 7: Implement the `AppShell` wiring**

Replace `apps/web/src/components/shell/AppShell.tsx`:

```tsx
"use client";

import { useEffect } from "react";
import type { ReactNode } from "react";
import { Sidebar } from "./Sidebar";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettings } from "@/lib/useSettings";

export function AppShell({ children }: { children: ReactNode }) {
  const { user } = useAuthUser();
  const { settings } = useSettings(user?.uid ?? null);

  useEffect(() => {
    if (!settings) return;
    if (settings.theme === "system") {
      document.documentElement.removeAttribute("data-theme");
    } else {
      document.documentElement.setAttribute("data-theme", settings.theme);
    }
  }, [settings]);

  const fontSizeClass =
    settings?.fontSize === "small"
      ? " fs-small"
      : settings?.fontSize === "large"
        ? " fs-large"
        : "";

  return (
    <div className={`app-frame${fontSizeClass}`}>
      <Sidebar />
      <main className="main">{children}</main>
    </div>
  );
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 9: Append the font-size CSS to `bloom.css`**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.app-frame.fs-small {
  zoom: 0.9;
}

.app-frame.fs-large {
  zoom: 1.15;
}
```

- [ ] **Step 10: Run the full suite to verify everything still passes**

Run: `npm --prefix apps/web test`
Expected: PASS — includes the other screens that render inside `AppShell` (e.g. `vocab-bank/page.test.tsx`), which must still pass now that `AppShell` calls `useAuthUser`/`useSettings`. If any such test fails because it doesn't mock `@/lib/useSettings`, that test file needs `vi.mock("@/lib/useSettings", () => ({ useSettings: vi.fn(() => ({ settings: null, loading: false, error: null, save: vi.fn() })) }))` added alongside its existing `@/lib/useAuthUser` mock — check each failure individually rather than assuming this blanket fix is needed everywhere.

- [ ] **Step 11: Commit**

```bash
git add apps/web/src/components/settings/AppearanceSection.tsx apps/web/src/components/settings/AppearanceSection.test.tsx apps/web/src/components/shell/AppShell.tsx apps/web/src/components/shell/AppShell.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): wire theme + font-size into AppShell, add AppearanceSection UI"
```

---

## Task 7: `AccountSection` + `DangerZoneSection` components

**Files:**
- Create: `apps/web/src/components/settings/AccountSection.tsx`
- Create: `apps/web/src/components/settings/AccountSection.test.tsx`
- Create: `apps/web/src/components/settings/DangerZoneSection.tsx`
- Create: `apps/web/src/components/settings/DangerZoneSection.test.tsx`

**Interfaces:**
- Consumes: `signOutOfFirebase` (`@/lib/auth`), `User` type (`firebase/auth`).
- Produces: `<AccountSection user />`, `<DangerZoneSection />` — used by Task 8.

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/components/settings/AccountSection.test.tsx`:

```tsx
import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { AccountSection } from "./AccountSection";
import type { User } from "firebase/auth";

describe("AccountSection", () => {
  it("renders the signed-in user's display name and email", () => {
    const user = { displayName: "Tùng Nguyễn", email: "tung@example.com" } as User;
    render(<AccountSection user={user} />);
    expect(screen.getByText("Tùng Nguyễn")).toBeInTheDocument();
    expect(screen.getByText("tung@example.com")).toBeInTheDocument();
  });
});
```

Create `apps/web/src/components/settings/DangerZoneSection.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { DangerZoneSection } from "./DangerZoneSection";
import { signOutOfFirebase } from "@/lib/auth";

vi.mock("@/lib/auth", () => ({ signOutOfFirebase: vi.fn() }));

describe("DangerZoneSection", () => {
  it("calls signOutOfFirebase when Đăng xuất is clicked", () => {
    render(<DangerZoneSection />);
    fireEvent.click(screen.getByRole("button", { name: "Đăng xuất" }));
    expect(signOutOfFirebase).toHaveBeenCalledOnce();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm --prefix apps/web test`
Expected: FAIL — neither component exists.

- [ ] **Step 3: Implement both components**

Create `apps/web/src/components/settings/AccountSection.tsx`:

```tsx
import type { User } from "firebase/auth";

interface AccountSectionProps {
  user: User;
}

export function AccountSection({ user }: AccountSectionProps) {
  return (
    <section>
      <h3 className="scr-title">Tài khoản</h3>
      <p>{user.displayName}</p>
      <p>{user.email}</p>
    </section>
  );
}
```

Create `apps/web/src/components/settings/DangerZoneSection.tsx`:

```tsx
"use client";

import { signOutOfFirebase } from "@/lib/auth";

export function DangerZoneSection() {
  return (
    <section>
      <h3 className="scr-title">Vùng nguy hiểm</h3>
      <button className="danger" onClick={() => void signOutOfFirebase()}>
        Đăng xuất
      </button>
    </section>
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/settings/AccountSection.tsx apps/web/src/components/settings/AccountSection.test.tsx apps/web/src/components/settings/DangerZoneSection.tsx apps/web/src/components/settings/DangerZoneSection.test.tsx
git commit -m "feat(web): add AccountSection and DangerZoneSection (sign-out only)"
```

---

## Task 8: Assemble the `/settings` page

**Files:**
- Create: `apps/web/src/app/(app)/settings/page.tsx`
- Create: `apps/web/src/app/(app)/settings/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append `.danger` button styling if not already present — see Step 4)

**Interfaces:**
- Consumes: `useAuthUser` (`@/lib/useAuthUser`), `useSettings` (`@/lib/useSettings`, Task 3), `SignInButton` (`@/components/SignInButton`), `AccountSection`/`AiProviderSection`/`AppearanceSection`/`DangerZoneSection` (Tasks 5-7).
- Produces: the real `/settings` route (the Sidebar link from React Web Plan 3 Phase A currently 404s here — this task makes it resolve).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/app/(app)/settings/page.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import SettingsPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettings } from "@/lib/useSettings";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/useSettings", () => ({ useSettings: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

describe("SettingsPage", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: null,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(<SettingsPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("renders every section once settings have loaded", async () => {
    const user = { uid: "u1", displayName: "Tùng", email: "tung@example.com" };
    vi.mocked(useAuthUser).mockReturnValue({ user, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(<SettingsPage />);

    expect(await screen.findByText("Tài khoản")).toBeInTheDocument();
    expect(screen.getByText("AI Provider & API Key")).toBeInTheDocument();
    expect(screen.getByText("Giao diện")).toBeInTheDocument();
    expect(screen.getByText("Vùng nguy hiểm")).toBeInTheDocument();
  });

  it("shows a loading state while settings are loading", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: null,
      loading: true,
      error: null,
      save: vi.fn(),
    });

    render(<SettingsPage />);
    expect(screen.getByText("Đang tải cài đặt…")).toBeInTheDocument();
  });

  it("shows an alert when settings fail to load", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettings).mockReturnValue({
      settings: null,
      loading: false,
      error: "offline",
      save: vi.fn(),
    });

    render(<SettingsPage />);
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("offline"));
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./page` does not exist under `settings/`.

- [ ] **Step 3: Implement the page**

Create `apps/web/src/app/(app)/settings/page.tsx`:

```tsx
"use client";

import { useAuthUser } from "@/lib/useAuthUser";
import { useSettings } from "@/lib/useSettings";
import { SignInButton } from "@/components/SignInButton";
import { AccountSection } from "@/components/settings/AccountSection";
import { AiProviderSection } from "@/components/settings/AiProviderSection";
import { AppearanceSection } from "@/components/settings/AppearanceSection";
import { DangerZoneSection } from "@/components/settings/DangerZoneSection";

export default function SettingsPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading, error, save } = useSettings(user?.uid ?? null);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Cài đặt</h2>
        <p className="scr-sub">Đăng nhập để xem cài đặt.</p>
        <SignInButton />
      </div>
    );
  }

  if (error) return <p role="alert">Lỗi: {error}</p>;
  if (settingsLoading || !settings) return <p>Đang tải cài đặt…</p>;

  return (
    <>
      <h2 className="scr-title">Cài đặt</h2>
      <AccountSection user={user} />
      <AiProviderSection settings={settings} onSave={save} />
      <AppearanceSection settings={settings} onSave={save} />
      <DangerZoneSection />
    </>
  );
}
```

- [ ] **Step 4: Append `.danger` button styling if not already defined**

Run: `grep -n "\.danger" apps/web/src/styles/bloom.css`

If this prints no match, append to `apps/web/src/styles/bloom.css`:

```css

button.danger {
  background: var(--danger-bg);
  color: var(--danger);
  border: 1px solid var(--danger);
  border-radius: 999px;
  padding: 8px 16px;
  font-weight: 700;
  cursor: pointer;
}
```

If it does print a match (the Vocab Bank Polish plan may already have added `.fa button.danger` or similar), read the surrounding lines and reuse the existing class instead of adding a duplicate/conflicting rule.

- [ ] **Step 5: Run the full suite to verify everything passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/settings" apps/web/src/styles/bloom.css
git commit -m "feat(web): assemble the /settings page from all sections"
```

---

## Task 9: Live GCP infrastructure — Cloud KMS setup, deploy, manual E2E verification

**This task requires live infrastructure changes and human interaction (gcloud/Firebase CLI, real GCP project access) — do NOT dispatch this task to a subagent. Work through it directly with the user, the same way React Web Plan 2's Task 9 (Docker build/push, Cloud Run deploy, IAM grants) was done.**

**Files:**
- Modify: `functions/.env` (add real KMS config values)
- Modify: `.superpowers/sdd/progress.md` (ledger entry for this plan, mirroring the React Web Plan 1/2 entries' format)

- [ ] **Step 1: Enable the Cloud KMS API**

Run: `gcloud services enable cloudkms.googleapis.com --project=lexi-core`

- [ ] **Step 2: Create the keyring and crypto key in `asia-southeast1`**

Run:
```bash
gcloud kms keyrings create lexicore-keys --location=asia-southeast1 --project=lexi-core
gcloud kms keys create byok-api-keys --location=asia-southeast1 --keyring=lexicore-keys --purpose=encryption --project=lexi-core
```

- [ ] **Step 3: Confirm the real Cloud Functions runtime service account**

Run: `gcloud functions describe generateContent --gen2 --region=asia-southeast1 --project=lexi-core --format="value(serviceConfig.serviceAccountEmail)"`

Do not assume the value — React Web Plan 2's notes recorded the actual SA (`243190098866-compute@developer.gserviceaccount.com`) differing from an earlier guess. Use whatever this command actually prints in the next step.

- [ ] **Step 4: Grant the runtime service account permission to use the key**

Run (substituting the real SA from Step 3):
```bash
gcloud kms keys add-iam-policy-binding byok-api-keys \
  --location=asia-southeast1 --keyring=lexicore-keys \
  --member="serviceAccount:<SA_FROM_STEP_3>" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" \
  --project=lexi-core
```

- [ ] **Step 5: Add the real KMS config to `functions/.env`**

Modify `functions/.env`:

```
# Base URL of the deployed Cloud Run TTS/STT service (services/tts-stt/).
# Non-secret — just a URL, safe to commit.
TTS_STT_SERVICE_URL=https://tts-stt-243190098866.asia-southeast1.run.app

# Cloud KMS key used by encryptApiKey/generateContent to encrypt/decrypt
# the user's BYOK API key at rest in Firestore. Non-secret — these are
# resource identifiers, not the key material itself.
KMS_PROJECT_ID=lexi-core
KMS_LOCATION=asia-southeast1
KMS_KEY_RING=lexicore-keys
KMS_KEY_NAME=byok-api-keys
```

- [ ] **Step 6: Deploy the updated/new functions**

Run: `firebase deploy --only functions:generateContent,functions:encryptApiKey`
Expected: both functions deploy successfully in `asia-southeast1`.

If this fails with `Cannot determine backend specification. Timeout after 10000` — this is a known Firebase CLI flake (seen during React Web Plan 2), retry immediately.

- [ ] **Step 7: Verify Firestore security rules cover the new `settings` subcollection**

Confirm (via Firebase Console → Firestore → Rules, or `firebase firestore:rules`) that `users/{uid}/settings/{document=**}` is covered by the same owner-only rule as `vocab_records`/`topics` (`request.auth.uid == uid` on read AND write). This collection is more sensitive than the others — it holds ciphertext of the user's API key. If no rule explicitly covers it, add one before proceeding, matching the existing rule's pattern exactly.

- [ ] **Step 8: Manual end-to-end verification with the user**

With the user, run `npm --prefix apps/web run dev`, sign in with the real Google account, go to `/settings`, and:
1. Enter a real (or throwaway/dummy) API key for Gemini, click Cập nhật — confirm it succeeds with no error.
2. Reload the page — confirm the API key field shows the masked placeholder (proves the ciphertext round-tripped through Firestore and the page re-read it).
3. Switch theme to Tối (dark) — confirm the whole app visibly switches to dark mode immediately, not just the Settings screen.
4. Switch font size to Lớn (large) — confirm text visibly scales up across the app frame.
5. Click Đăng xuất — confirm it signs out and redirects to the sign-in prompt.

Do not skip this — every prior React Web Plan's final task included a real production verification, not just green tests against mocks.

- [ ] **Step 9: Update the SDD progress ledger**

Modify `.superpowers/sdd/progress.md` — add a new section at the end following the exact format of the existing React Web Plan 3 Phase A entry (task-by-task status lines, final test counts, final whole-branch review note once that review has actually been run separately from this plan's own execution).

- [ ] **Step 10: Commit**

```bash
git add functions/.env .superpowers/sdd/progress.md
git commit -m "feat(functions): deploy Cloud KMS BYOK encryption live, verify end-to-end in production"
```
