# LexiCore Web — Backend/Infra Core (Plan 1 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the foundational plumbing for the new React web app — a Next.js app on Firebase App Hosting that signs in with Google, reads the signed-in user's own Firestore data, and calls a real LLM provider through a Cloud Functions proxy — proving every piece of the new architecture works end-to-end before any real screen UI is built.

**Architecture:** Two new sibling directories added to the existing monorepo: `apps/web/` (Next.js, App Router, TypeScript) for the frontend, and `functions/` (Firebase Cloud Functions v2, TypeScript) for a thin `onCall` proxy to Gemini/Groq/OpenRouter. The frontend talks to Firestore/Auth **directly** via the Firebase JS SDK — reusing the existing security rules and the same Firebase project (`lexi-core`) the Flutter app already uses. The backend is called for exactly one thing: the BYOK-authenticated LLM call, which must not run in the browser (this is where the user's provider API key would otherwise be visible to third-party domains in the browser's network tab).

**Tech Stack:** Next.js 16 (App Router) + React 19 + TypeScript on the frontend; Firebase Functions v2 + TypeScript on the backend; Firebase JS SDK v12 (`firebase/app`, `firebase/auth`, `firebase/firestore`, `firebase/functions`) for client wiring; Vitest + React Testing Library for tests on both sides; Firebase App Hosting for the frontend deploy, `firebase deploy --only functions` for the backend.

## Global Constraints

- Monorepo, one GitHub repo (this repo). Next.js app goes in `apps/web/` — **never** `web/` (that's Flutter's own web-platform scaffold that `firebase build web`/`firebase.json`'s classic `hosting.public` already uses; reusing the name silently collides with it).
- Cloud Functions code goes in `functions/` (Firebase CLI's own convention).
- Firestore/Auth access is **client-side only**, via the Firebase JS SDK. The backend never proxies Firestore or Auth, and existing Firestore security rules are reused unchanged — no rule changes in this plan.
- Every AI-proxy Cloud Function must reject unauthenticated callers. `onCall` automatically verifies a token's signature **if one is present**, but does **not** automatically reject a call with no token at all — every handler needs an explicit `if (!request.auth) throw new HttpsError("unauthenticated", ...)` check.
- BYOK: the user's own provider API key travels in the callable's `data` payload (never a URL query string, which would leak into logs), is used in-memory for one upstream call, and is never logged or persisted server-side.
- Node 22 (Cloud Functions runtime; bumped from Node 20 post-Plan-1 hardening pass — see `functions/package.json`'s `engines` field and CLAUDE.md's Deploy gotchas).
- No TTS/STT anywhere in this plan — that's Plan 2 (`getPronunciation`, `transcribeAudio`), a separate deployable Cloud Run service. This plan only builds the `generateContent` LLM proxy.
- Reference doc for all architecture decisions and their reasoning: `docs/superpowers/specs/2026-08-11-react-web-redesign-design.md`.

---

## Task 1: Scaffold the Next.js app in `apps/web/`

**Files:**
- Create: `apps/web/package.json`
- Create: `apps/web/tsconfig.json`
- Create: `apps/web/next.config.ts`
- Create: `apps/web/next-env.d.ts`
- Create: `apps/web/vitest.config.ts`
- Create: `apps/web/vitest.setup.ts`
- Create: `apps/web/src/app/layout.tsx`
- Create: `apps/web/src/app/page.tsx`
- Create: `apps/web/src/app/page.test.tsx`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `apps/web/src/app/page.tsx` exports default `HomePage` — later tasks (4, 5, 7) add components to this page.
- Produces: path alias `@/*` → `apps/web/src/*`, configured in both `tsconfig.json` and `vitest.config.ts` — every later task's imports use it.

- [ ] **Step 1: Create the package manifest**

`apps/web/package.json`:
```json
{
  "name": "lexicore-web",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "test": "vitest run"
  },
  "dependencies": {
    "next": "16.3.0",
    "react": "19.2.8",
    "react-dom": "19.2.8",
    "firebase": "12.17.1"
  },
  "devDependencies": {
    "typescript": "7.0.2",
    "@types/node": "26.2.0",
    "@types/react": "19.2.18",
    "@types/react-dom": "19.2.4",
    "vitest": "4.1.10",
    "@vitejs/plugin-react": "6.0.5",
    "@testing-library/react": "16.3.2",
    "@testing-library/jest-dom": "7.0.1",
    "jsdom": "29.1.1"
  }
}
```

- [ ] **Step 2: Create the TypeScript config**

`apps/web/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

- [ ] **Step 3: Create the Next.js and environment config files**

`apps/web/next.config.ts`:
```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {};

export default nextConfig;
```

`apps/web/next-env.d.ts`:
```ts
/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/app/api-reference/config/typescript for more information.
```

- [ ] **Step 4: Create the Vitest config**

`apps/web/vitest.config.ts`:
```ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "node:path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
    globals: true,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

`apps/web/vitest.setup.ts`:
```ts
import "@testing-library/jest-dom/vitest";
```

- [ ] **Step 5: Install dependencies**

Run: `npm --prefix apps/web install`
Expected: installs without error, creates `apps/web/node_modules` and `apps/web/package-lock.json`.

- [ ] **Step 6: Write the failing test**

`apps/web/src/app/page.test.tsx`:
```tsx
import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import HomePage from "./page";

describe("HomePage", () => {
  it("renders the LexiCore Web heading", () => {
    render(<HomePage />);
    expect(screen.getByRole("heading", { name: "LexiCore Web" })).toBeInTheDocument();
  });
});
```

- [ ] **Step 7: Run the test and verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./page` (i.e. `apps/web/src/app/page.tsx`) does not exist yet.

- [ ] **Step 8: Write the minimal implementation**

`apps/web/src/app/layout.tsx`:
```tsx
import type { ReactNode } from "react";

export const metadata = {
  title: "LexiCore",
  description: "Personal Vietnamese-first language-learning app",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="vi">
      <body>{children}</body>
    </html>
  );
}
```

`apps/web/src/app/page.tsx`:
```tsx
export default function HomePage() {
  return (
    <main>
      <h1>LexiCore Web</h1>
    </main>
  );
}
```

- [ ] **Step 9: Run the test and verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — 1 test passed.

- [ ] **Step 10: Ignore build output**

Add to `.gitignore` (the repo already has a blanket `**/node_modules/` rule — this only needs the Next.js build artifact):
```
# Next.js (apps/web)
apps/web/.next/
```

- [ ] **Step 11: Commit**

```bash
git add apps/web .gitignore
git commit -m "feat(web): scaffold Next.js app with Vitest"
```

---

## Task 2: Scaffold the `functions/` Cloud Functions project with a `ping` health-check function

**Files:**
- Create: `functions/package.json`
- Create: `functions/tsconfig.json`
- Create: `functions/vitest.config.mts` (note: `.mts`, not `.ts` — see Step 3)
- Create: `functions/src/ping.ts`
- Create: `functions/src/ping.test.ts`
- Create: `functions/src/index.ts`
- Modify: `firebase.json`

**Interfaces:**
- Produces: `functions/src/ping.ts` exports `pingHandler(request: CallableRequest<unknown>)` and `ping` (the `onCall`-wrapped export) — establishes the handler/wrapper split pattern Task 6 (`generateContent`) follows.
- Produces: `functions/src/index.ts` re-exports every deployable function — Task 6 adds `generateContent` here.

- [ ] **Step 1: Create the package manifest**

`functions/package.json`:
```json
{
  "name": "functions",
  "version": "0.1.0",
  "private": true,
  "type": "commonjs",
  "main": "lib/index.js",
  "engines": { "node": "20" },
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "test": "vitest run"
  },
  "dependencies": {
    "firebase-functions": "7.3.2"
  },
  "devDependencies": {
    "typescript": "7.0.2",
    "vitest": "4.1.10"
  }
}
```

- [ ] **Step 2: Create the TypeScript config**

`functions/tsconfig.json`:
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "target": "es2021",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "moduleResolution": "node"
  },
  "compileOnSave": true,
  "include": ["src"]
}
```

- [ ] **Step 3: Create the Vitest config**

Use the `.mts` extension, not `.ts` — `functions/package.json` sets `"type": "commonjs"`, and a plain `.ts` config file using `import`/`export` syntax there triggers Vite's "native configLoader" warning and an intermittent cold-start crash (`TypeError: Cannot read properties of undefined (reading 'config')`, 0 tests collected) found and fixed during this plan's own execution. `.mts` tells Node/Vite unambiguously this file is ESM regardless of the package's `"type"`, eliminating the ambiguity.

This config also needs a plugin forcing a single resolved copy of `firebase-functions`: it ships separate ESM (`.mjs`) and CommonJS (`.js`) builds of the same modules, and without this, Vitest's test files (loaded via Node's native ESM loader → the `.mjs` build) and source files like `ping.ts` (loaded via vite-node's SSR runner → the `.js` build) resolve to two different physical files — so `expect(...).toThrow(HttpsError)` fails even when the thrown error is structurally correct, because it's `instanceof` a different class object than the one the test imported.

`functions/vitest.config.mts`:
```ts
import { createRequire } from "node:module";
import { defineConfig, type Plugin } from "vitest/config";

const require = createRequire(import.meta.url);

function singleInstanceFirebaseFunctions(): Plugin {
  return {
    name: "single-instance-firebase-functions",
    enforce: "pre",
    resolveId(source) {
      if (source === "firebase-functions" || source.startsWith("firebase-functions/")) {
        return require.resolve(source);
      }
      return null;
    },
  };
}

export default defineConfig({
  plugins: [singleInstanceFirebaseFunctions()],
  test: {
    environment: "node",
    globals: true,
  },
});
```

- [ ] **Step 4: Install dependencies**

Run: `npm --prefix functions install`
Expected: installs without error, creates `functions/node_modules` and `functions/package-lock.json`.

- [ ] **Step 5: Write the failing test**

`functions/src/ping.test.ts`:
```ts
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
```

- [ ] **Step 6: Run the test and verify it fails**

Run: `npm --prefix functions test`
Expected: FAIL — `./ping` (i.e. `functions/src/ping.ts`) does not exist yet.

- [ ] **Step 7: Write the minimal implementation**

`functions/src/ping.ts`:
```ts
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";

export function pingHandler(request: CallableRequest<unknown>) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return { message: `pong, ${request.auth.uid}` };
}

export const ping = onCall(pingHandler);
```

`functions/src/index.ts`:
```ts
export { ping } from "./ping";
```

- [ ] **Step 8: Run the test and verify it passes**

Run: `npm --prefix functions test`
Expected: PASS — 2 tests passed.

- [ ] **Step 9: Register the functions codebase and emulator ports in `firebase.json`**

Modify `firebase.json` — add `"functions"` and `"emulators"` as new top-level keys, siblings of the existing `"flutter"` and `"hosting"` keys. The file currently ends like this:

```json
      {
        "source": "/version.json",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      }
    ]
  }
}
```

Change the final `}` that closes `"hosting"` and the file to:

```json
      {
        "source": "/version.json",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      }
    ]
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log",
        "*.local"
      ],
      "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
    }
  ],
  "emulators": {
    "functions": { "port": 5001 },
    "ui": { "enabled": true }
  }
}
```

(i.e. the `"hosting"` object's closing `}` gets a trailing comma, then the two new keys are added before the file's final closing `}`.)

- [ ] **Step 10: Verify the build compiles**

Run: `npm --prefix functions run build`
Expected: no TypeScript errors; creates `functions/lib/index.js` and `functions/lib/ping.js`.

- [ ] **Step 11: Commit**

```bash
git add functions firebase.json
git commit -m "feat(functions): scaffold Cloud Functions project with ping health check"
```

---

## Task 3: Firebase client SDK wiring in Next.js

**Files:**
- Create: `apps/web/.env.local.example`
- Create: `apps/web/.env.local` (local only — gitignored, not committed)
- Create: `apps/web/src/lib/firebase.ts`
- Create: `apps/web/src/lib/firebase.test.ts`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `apps/web/src/lib/firebase.ts` exports `getFirebaseConfig()`, `getFirebaseApp()`, `getFirebaseAuth()`, `getFirebaseDb()`, `getFirebaseFunctions()` — Tasks 4, 5, 7, 8 all import from this module.

- [ ] **Step 1: Ignore local env files**

Add to `.gitignore`:
```
# Local env files (apps/web) — Firebase web config is not secret, but keep the
# convention of not committing .env*.local anyway.
apps/web/.env*.local
```

- [ ] **Step 2: Create the example env file with the real (non-secret) Firebase Web config**

This reuses the same Firebase project's existing Web app registration that Flutter Web already uses (`lib/firebase_options.dart`) — Firebase client config (`apiKey` included) is not a secret; it identifies the project, it doesn't grant access. Access is controlled by Firestore/Storage security rules and Firebase Auth, not by hiding this value.

`apps/web/.env.local.example`:
```
# Firebase Web config — not secret, safe to have real values here.
# Reused from the existing Flutter Web app registration (lib/firebase_options.dart).
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyBsAgOmBo9WroNzoz1h5IH915FhNxn8OYQ
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=lexi-core.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=lexi-core
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=lexi-core.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=243190098866
NEXT_PUBLIC_FIREBASE_APP_ID=1:243190098866:web:0be910ac66637c3bddd2ab
```

- [ ] **Step 3: Create the real local env file**

Run: `cp apps/web/.env.local.example apps/web/.env.local` (or copy by hand on Windows)
Expected: `apps/web/.env.local` exists with the same content as the example (this file is gitignored — it's the one Next.js actually reads at dev/build time).

- [ ] **Step 4: Write the failing test**

`apps/web/src/lib/firebase.test.ts`:
```ts
import { describe, expect, it, beforeEach, afterEach } from "vitest";
import { getFirebaseConfig } from "./firebase";

const ENV_KEYS = [
  "NEXT_PUBLIC_FIREBASE_API_KEY",
  "NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN",
  "NEXT_PUBLIC_FIREBASE_PROJECT_ID",
  "NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET",
  "NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID",
  "NEXT_PUBLIC_FIREBASE_APP_ID",
] as const;

function setAllEnvVars() {
  process.env.NEXT_PUBLIC_FIREBASE_API_KEY = "test-api-key";
  process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN = "lexi-core.firebaseapp.com";
  process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID = "lexi-core";
  process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET = "lexi-core.firebasestorage.app";
  process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID = "243190098866";
  process.env.NEXT_PUBLIC_FIREBASE_APP_ID = "1:243190098866:web:test";
}

describe("getFirebaseConfig", () => {
  const original: Record<string, string | undefined> = {};

  beforeEach(() => {
    for (const key of ENV_KEYS) {
      original[key] = process.env[key];
      delete process.env[key];
    }
  });

  afterEach(() => {
    for (const key of ENV_KEYS) {
      if (original[key] === undefined) delete process.env[key];
      else process.env[key] = original[key];
    }
  });

  it("returns the config when every env var is set", () => {
    setAllEnvVars();
    expect(getFirebaseConfig()).toEqual({
      apiKey: "test-api-key",
      authDomain: "lexi-core.firebaseapp.com",
      projectId: "lexi-core",
      storageBucket: "lexi-core.firebasestorage.app",
      messagingSenderId: "243190098866",
      appId: "1:243190098866:web:test",
    });
  });

  it("throws when a required env var is missing", () => {
    setAllEnvVars();
    delete process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
    expect(() => getFirebaseConfig()).toThrow(/Missing Firebase config/);
  });
});
```

- [ ] **Step 5: Run the test and verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./firebase` does not exist yet.

- [ ] **Step 6: Write the minimal implementation**

`apps/web/src/lib/firebase.ts`:
```ts
import { initializeApp, getApps, getApp, type FirebaseOptions } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getFunctions } from "firebase/functions";

export function getFirebaseConfig(): FirebaseOptions {
  const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
  const authDomain = process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN;
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const storageBucket = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET;
  const messagingSenderId = process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID;
  const appId = process.env.NEXT_PUBLIC_FIREBASE_APP_ID;

  if (
    !apiKey ||
    !authDomain ||
    !projectId ||
    !storageBucket ||
    !messagingSenderId ||
    !appId
  ) {
    throw new Error(
      "Missing Firebase config env vars — check apps/web/.env.local against .env.local.example."
    );
  }

  return { apiKey, authDomain, projectId, storageBucket, messagingSenderId, appId };
}

export function getFirebaseApp() {
  return getApps().length ? getApp() : initializeApp(getFirebaseConfig());
}

export function getFirebaseAuth() {
  return getAuth(getFirebaseApp());
}

export function getFirebaseDb() {
  return getFirestore(getFirebaseApp());
}

export function getFirebaseFunctions() {
  return getFunctions(getFirebaseApp());
}
```

- [ ] **Step 7: Run the test and verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — all tests passed (3 total: 1 from Task 1, 2 from this task).

- [ ] **Step 8: Commit**

```bash
git add apps/web .gitignore
git commit -m "feat(web): wire Firebase client SDK config"
```

---

## Task 4: Google Sign-In

**Files:**
- Create: `apps/web/src/lib/auth.ts`
- Create: `apps/web/src/lib/useAuthUser.ts`
- Create: `apps/web/src/components/SignInButton.tsx`
- Create: `apps/web/src/components/SignInButton.test.tsx`
- Modify: `apps/web/src/app/page.tsx`

**Interfaces:**
- Consumes: `getFirebaseAuth()` from `apps/web/src/lib/firebase.ts` (Task 3).
- Produces: `apps/web/src/lib/useAuthUser.ts` exports `useAuthUser()` → `{ user: User | null, loading: boolean }` — Task 5 and Task 7's components consume this.
- Produces: `apps/web/src/components/SignInButton.tsx` exports `SignInButton`.

- [ ] **Step 1: Write `auth.ts` (no test needed — thin wrapper around the Firebase SDK, covered indirectly by Step 4's component test which mocks this module)**

`apps/web/src/lib/auth.ts`:
```ts
import {
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut,
  type User,
} from "firebase/auth";
import { getFirebaseAuth } from "./firebase";

const googleProvider = new GoogleAuthProvider();

export async function signInWithGoogle(): Promise<User> {
  const credential = await signInWithPopup(getFirebaseAuth(), googleProvider);
  return credential.user;
}

export async function signOutOfFirebase(): Promise<void> {
  await signOut(getFirebaseAuth());
}

export function subscribeToAuthState(
  callback: (user: User | null) => void
): () => void {
  return onAuthStateChanged(getFirebaseAuth(), callback);
}
```

- [ ] **Step 2: Write `useAuthUser.ts`**

`apps/web/src/lib/useAuthUser.ts`:
```ts
"use client";

import { useEffect, useState } from "react";
import type { User } from "firebase/auth";
import { subscribeToAuthState } from "./auth";

export function useAuthUser() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    return subscribeToAuthState((nextUser) => {
      setUser(nextUser);
      setLoading(false);
    });
  }, []);

  return { user, loading };
}
```

- [ ] **Step 3: Write the failing test for `SignInButton`**

`apps/web/src/components/SignInButton.test.tsx`:
```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { SignInButton } from "./SignInButton";
import { signInWithGoogle, signOutOfFirebase } from "@/lib/auth";
import { useAuthUser } from "@/lib/useAuthUser";

vi.mock("@/lib/auth", () => ({
  signInWithGoogle: vi.fn(),
  signOutOfFirebase: vi.fn(),
}));

vi.mock("@/lib/useAuthUser", () => ({
  useAuthUser: vi.fn(),
}));

describe("SignInButton", () => {
  it("shows a loading state while auth is resolving", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: true });
    render(<SignInButton />);
    expect(screen.getByRole("button", { name: "Đang tải…" })).toBeDisabled();
  });

  it("shows a sign-in button and calls signInWithGoogle when signed out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    render(<SignInButton />);
    fireEvent.click(screen.getByRole("button", { name: "Đăng nhập với Google" }));
    expect(signInWithGoogle).toHaveBeenCalledOnce();
  });

  it("shows the user's name and calls signOutOfFirebase when signed in", () => {
    vi.mocked(useAuthUser).mockReturnValue({
      user: { displayName: "Nguyễn Anh", email: "anh@example.com" } as never,
      loading: false,
    });
    render(<SignInButton />);
    fireEvent.click(
      screen.getByRole("button", { name: "Đăng xuất (Nguyễn Anh)" })
    );
    expect(signOutOfFirebase).toHaveBeenCalledOnce();
  });
});
```

- [ ] **Step 4: Run the test and verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./SignInButton` does not exist yet.

- [ ] **Step 5: Write the minimal implementation**

`apps/web/src/components/SignInButton.tsx`:
```tsx
"use client";

import { signInWithGoogle, signOutOfFirebase } from "@/lib/auth";
import { useAuthUser } from "@/lib/useAuthUser";

export function SignInButton() {
  const { user, loading } = useAuthUser();

  if (loading) {
    return <button disabled>Đang tải…</button>;
  }

  if (user) {
    return (
      <button onClick={() => void signOutOfFirebase()}>
        Đăng xuất ({user.displayName ?? user.email})
      </button>
    );
  }

  return (
    <button onClick={() => void signInWithGoogle()}>
      Đăng nhập với Google
    </button>
  );
}
```

- [ ] **Step 6: Run the test and verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — all tests passed.

- [ ] **Step 7: Mount `SignInButton` on the home page**

Modify `apps/web/src/app/page.tsx`:
```tsx
import { SignInButton } from "@/components/SignInButton";

export default function HomePage() {
  return (
    <main>
      <h1>LexiCore Web</h1>
      <SignInButton />
    </main>
  );
}
```

- [ ] **Step 8: Commit**

```bash
git add apps/web
git commit -m "feat(web): add Google Sign-In"
```

---

## Task 5: Firestore read smoke test (client-side, reusing existing security rules)

**Files:**
- Create: `apps/web/src/lib/vocabRecords.ts`
- Create: `apps/web/src/lib/vocabRecords.test.ts`
- Create: `apps/web/src/components/VocabRecordCount.tsx`
- Create: `apps/web/src/components/VocabRecordCount.test.tsx`
- Modify: `apps/web/src/app/page.tsx`

**Context:** the existing Flutter sync code (`lib/core/services/sync_service.dart:46-50`) reads/writes `users/{uid}/vocab_records` and `users/{uid}/topics` as subcollections of `users/{uid}`. This task reuses that exact, already-proven-allowed path — a read-only count of the signed-in user's own `vocab_records` subcollection — rather than guessing at a schema, and never writes anything (no risk to real data).

**Interfaces:**
- Consumes: `getFirebaseDb()` from `apps/web/src/lib/firebase.ts` (Task 3), `useAuthUser()` from Task 4.
- Produces: `apps/web/src/lib/vocabRecords.ts` exports `countVocabRecords(uid: string): Promise<number>`.

- [ ] **Step 1: Write the failing test for `countVocabRecords`**

`apps/web/src/lib/vocabRecords.test.ts`:
```ts
import { describe, expect, it, vi } from "vitest";
import { getDocs } from "firebase/firestore";
import { countVocabRecords } from "./vocabRecords";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  getDocs: vi.fn(),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

describe("countVocabRecords", () => {
  it("returns the number of documents in the user's vocab_records subcollection", async () => {
    vi.mocked(getDocs).mockResolvedValue({ size: 3 } as never);
    const count = await countVocabRecords("user-123");
    expect(count).toBe(3);
  });
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./vocabRecords` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

`apps/web/src/lib/vocabRecords.ts`:
```ts
import { collection, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";

export async function countVocabRecords(uid: string): Promise<number> {
  const col = collection(getFirebaseDb(), "users", uid, "vocab_records");
  const snapshot = await getDocs(col);
  return snapshot.size;
}
```

- [ ] **Step 4: Run the test and verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — all tests passed.

- [ ] **Step 5: Write the failing test for the `VocabRecordCount` component**

`apps/web/src/components/VocabRecordCount.test.tsx`:
```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { VocabRecordCount } from "./VocabRecordCount";
import { useAuthUser } from "@/lib/useAuthUser";
import { countVocabRecords } from "@/lib/vocabRecords";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ countVocabRecords: vi.fn() }));

describe("VocabRecordCount", () => {
  it("renders nothing when signed out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    const { container } = render(<VocabRecordCount />);
    expect(container).toBeEmptyDOMElement();
  });

  it("shows the vocab count once loaded for a signed-in user", async () => {
    vi.mocked(useAuthUser).mockReturnValue({
      user: { uid: "user-123" } as never,
      loading: false,
    });
    vi.mocked(countVocabRecords).mockResolvedValue(7);
    render(<VocabRecordCount />);
    await waitFor(() =>
      expect(
        screen.getByText("Bạn có 7 từ trong Ngân hàng từ vựng.")
      ).toBeInTheDocument()
    );
  });

  it("shows an error message if the Firestore read fails", async () => {
    vi.mocked(useAuthUser).mockReturnValue({
      user: { uid: "user-123" } as never,
      loading: false,
    });
    vi.mocked(countVocabRecords).mockRejectedValue(new Error("permission-denied"));
    render(<VocabRecordCount />);
    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent("permission-denied")
    );
  });
});
```

- [ ] **Step 6: Run the test and verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./VocabRecordCount` does not exist yet.

- [ ] **Step 7: Write the minimal implementation**

`apps/web/src/components/VocabRecordCount.tsx`:
```tsx
"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { countVocabRecords } from "@/lib/vocabRecords";

export function VocabRecordCount() {
  const { user } = useAuthUser();
  const [count, setCount] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) {
      setCount(null);
      return;
    }
    countVocabRecords(user.uid)
      .then(setCount)
      .catch((err: unknown) =>
        setError(err instanceof Error ? err.message : String(err))
      );
  }, [user]);

  if (!user) return null;
  if (error) return <p role="alert">Lỗi đọc Firestore: {error}</p>;
  if (count === null) return <p>Đang tải số từ vựng…</p>;
  return <p>Bạn có {count} từ trong Ngân hàng từ vựng.</p>;
}
```

- [ ] **Step 8: Run the test and verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — all tests passed.

- [ ] **Step 9: Mount `VocabRecordCount` on the home page**

Modify `apps/web/src/app/page.tsx`:
```tsx
import { SignInButton } from "@/components/SignInButton";
import { VocabRecordCount } from "@/components/VocabRecordCount";

export default function HomePage() {
  return (
    <main>
      <h1>LexiCore Web</h1>
      <SignInButton />
      <VocabRecordCount />
    </main>
  );
}
```

- [ ] **Step 10: Commit**

```bash
git add apps/web
git commit -m "feat(web): add Firestore read smoke test (vocab record count)"
```

---

## Task 6: `generateContent` Cloud Function — the real LLM proxy

**Files:**
- Create: `functions/src/providers/types.ts`
- Create: `functions/src/providers/gemini.ts`
- Create: `functions/src/providers/gemini.test.ts`
- Create: `functions/src/providers/openAiCompatible.ts`
- Create: `functions/src/providers/openAiCompatible.test.ts`
- Create: `functions/src/generateContent.ts`
- Create: `functions/src/generateContent.test.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: nothing from earlier tasks (self-contained backend module).
- Produces: `functions/src/generateContent.ts` exports `AiProvider` (`"gemini" | "groq" | "openrouter"`), `GenerateContentRequest` (`{provider, apiKey, model, prompt}`), `generateContentHandler(request)`, `generateContent` (the deployable `onCall`) — Task 7's client code and Task 8's manual verification both target this exact shape.

- [ ] **Step 1: Write the shared provider types**

`functions/src/providers/types.ts`:
```ts
export interface GenerateContentParams {
  apiKey: string;
  model: string;
  prompt: string;
}

export interface GenerateContentResult {
  text: string;
}
```

- [ ] **Step 2: Write the failing test for the Gemini provider**

`functions/src/providers/gemini.test.ts`:
```ts
import { describe, expect, it, vi } from "vitest";
import { callGemini } from "./gemini";

describe("callGemini", () => {
  it("sends the API key as a header, never a query string, and returns the text", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: "Xin chào" }] } }],
      }),
    });

    const result = await callGemini(
      { apiKey: "secret-key", model: "gemini-2.5-flash", prompt: "Say hi in Vietnamese" },
      mockFetch as unknown as typeof fetch
    );

    expect(result).toEqual({ text: "Xin chào" });
    const [url, options] = mockFetch.mock.calls[0];
    expect(url).toBe(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    );
    expect(url).not.toContain("secret-key");
    expect((options.headers as Record<string, string>)["x-goog-api-key"]).toBe(
      "secret-key"
    );
  });

  it("throws when the response has no candidates", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true, json: async () => ({}) });
    await expect(
      callGemini(
        { apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" },
        mockFetch as unknown as typeof fetch
      )
    ).rejects.toThrow("Gemini API returned no text.");
  });

  it("throws with the status and body when the response is not ok", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 429,
      text: async () => "rate limited",
    });
    await expect(
      callGemini(
        { apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" },
        mockFetch as unknown as typeof fetch
      )
    ).rejects.toThrow("Gemini API error: 429 rate limited");
  });
});
```

- [ ] **Step 3: Run the test and verify it fails**

Run: `npm --prefix functions test`
Expected: FAIL — `./gemini` does not exist yet.

- [ ] **Step 4: Write the minimal implementation**

`functions/src/providers/gemini.ts`:
```ts
import type { GenerateContentParams, GenerateContentResult } from "./types";

interface GeminiResponse {
  candidates?: Array<{
    content?: { parts?: Array<{ text?: string }> };
  }>;
}

export async function callGemini(
  { apiKey, model, prompt }: GenerateContentParams,
  fetchImpl: typeof fetch = fetch
): Promise<GenerateContentResult> {
  const response = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
      }),
    }
  );

  if (!response.ok) {
    throw new Error(`Gemini API error: ${response.status} ${await response.text()}`);
  }

  const data = (await response.json()) as GeminiResponse;
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Gemini API returned no text.");
  }
  return { text };
}
```

- [ ] **Step 5: Run the test and verify it passes**

Run: `npm --prefix functions test`
Expected: PASS.

- [ ] **Step 6: Write the failing test for the Groq/OpenRouter (OpenAI-compatible) provider**

`functions/src/providers/openAiCompatible.test.ts`:
```ts
import { describe, expect, it, vi } from "vitest";
import { callGroq, callOpenRouter } from "./openAiCompatible";

describe("callGroq", () => {
  it("calls the Groq chat completions endpoint with a Bearer token and returns the text", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ choices: [{ message: { content: "Xin chào từ Groq" } }] }),
    });

    const result = await callGroq(
      { apiKey: "secret-key", model: "llama-3.3-70b-versatile", prompt: "hi" },
      mockFetch as unknown as typeof fetch
    );

    expect(result).toEqual({ text: "Xin chào từ Groq" });
    const [url, options] = mockFetch.mock.calls[0];
    expect(url).toBe("https://api.groq.com/openai/v1/chat/completions");
    expect((options.headers as Record<string, string>).authorization).toBe(
      "Bearer secret-key"
    );
  });
});

describe("callOpenRouter", () => {
  it("calls the OpenRouter chat completions endpoint", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ choices: [{ message: { content: "hi from OpenRouter" } }] }),
    });

    const result = await callOpenRouter(
      { apiKey: "k", model: "meta-llama/llama-3.3-70b-instruct", prompt: "hi" },
      mockFetch as unknown as typeof fetch
    );

    expect(result).toEqual({ text: "hi from OpenRouter" });
    const [url] = mockFetch.mock.calls[0];
    expect(url).toBe("https://openrouter.ai/api/v1/chat/completions");
  });
});
```

- [ ] **Step 7: Run the test and verify it fails**

Run: `npm --prefix functions test`
Expected: FAIL — `./openAiCompatible` does not exist yet.

- [ ] **Step 8: Write the minimal implementation**

`functions/src/providers/openAiCompatible.ts`:
```ts
import type { GenerateContentParams, GenerateContentResult } from "./types";

interface ChatCompletionsResponse {
  choices?: Array<{ message?: { content?: string } }>;
}

export async function callOpenAiCompatible(
  baseUrl: string,
  { apiKey, model, prompt }: GenerateContentParams,
  fetchImpl: typeof fetch = fetch
): Promise<GenerateContentResult> {
  const response = await fetchImpl(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    throw new Error(`${baseUrl} API error: ${response.status} ${await response.text()}`);
  }

  const data = (await response.json()) as ChatCompletionsResponse;
  const text = data.choices?.[0]?.message?.content;
  if (!text) {
    throw new Error(`${baseUrl} API returned no text.`);
  }
  return { text };
}

export function callGroq(
  params: GenerateContentParams,
  fetchImpl?: typeof fetch
): Promise<GenerateContentResult> {
  return callOpenAiCompatible("https://api.groq.com/openai/v1", params, fetchImpl);
}

export function callOpenRouter(
  params: GenerateContentParams,
  fetchImpl?: typeof fetch
): Promise<GenerateContentResult> {
  return callOpenAiCompatible("https://openrouter.ai/api/v1", params, fetchImpl);
}
```

- [ ] **Step 9: Run the test and verify it passes**

Run: `npm --prefix functions test`
Expected: PASS.

- [ ] **Step 10: Write the failing test for `generateContentHandler`**

`functions/src/generateContent.test.ts`:
```ts
import { describe, expect, it, vi } from "vitest";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { generateContentHandler } from "./generateContent";
import { callGemini } from "./providers/gemini";
import { callGroq, callOpenRouter } from "./providers/openAiCompatible";

vi.mock("./providers/gemini", () => ({ callGemini: vi.fn() }));
vi.mock("./providers/openAiCompatible", () => ({
  callGroq: vi.fn(),
  callOpenRouter: vi.fn(),
}));

function makeRequest(data: unknown, authed = true): CallableRequest<unknown> {
  return {
    auth: authed ? { uid: "user-123" } : undefined,
    data,
  } as CallableRequest<unknown>;
}

describe("generateContentHandler", () => {
  it("throws unauthenticated when there is no auth context", async () => {
    await expect(
      generateContentHandler(
        makeRequest({ provider: "gemini", apiKey: "k", model: "m", prompt: "p" }, false)
      )
    ).rejects.toThrow(HttpsError);
  });

  it("throws invalid-argument for a malformed payload", async () => {
    await expect(
      generateContentHandler(makeRequest({ provider: "gemini" }))
    ).rejects.toThrow(HttpsError);
  });

  it("routes to callGemini for provider 'gemini'", async () => {
    vi.mocked(callGemini).mockResolvedValue({ text: "hello from gemini" });
    const result = await generateContentHandler(
      makeRequest({ provider: "gemini", apiKey: "k", model: "gemini-2.5-flash", prompt: "hi" })
    );
    expect(result).toEqual({ text: "hello from gemini" });
    expect(callGemini).toHaveBeenCalledWith({
      apiKey: "k",
      model: "gemini-2.5-flash",
      prompt: "hi",
    });
  });

  it("routes to callGroq for provider 'groq'", async () => {
    vi.mocked(callGroq).mockResolvedValue({ text: "hello from groq" });
    const result = await generateContentHandler(
      makeRequest({
        provider: "groq",
        apiKey: "k",
        model: "llama-3.3-70b-versatile",
        prompt: "hi",
      })
    );
    expect(result).toEqual({ text: "hello from groq" });
  });

  it("routes to callOpenRouter for provider 'openrouter'", async () => {
    vi.mocked(callOpenRouter).mockResolvedValue({ text: "hello from openrouter" });
    const result = await generateContentHandler(
      makeRequest({
        provider: "openrouter",
        apiKey: "k",
        model: "meta-llama/llama-3.3-70b-instruct",
        prompt: "hi",
      })
    );
    expect(result).toEqual({ text: "hello from openrouter" });
  });

  it("wraps a provider failure in an internal HttpsError", async () => {
    vi.mocked(callGemini).mockRejectedValue(
      new Error("Gemini API error: 429 rate limited")
    );
    await expect(
      generateContentHandler(
        makeRequest({
          provider: "gemini",
          apiKey: "k",
          model: "gemini-2.5-flash",
          prompt: "hi",
        })
      )
    ).rejects.toThrow(HttpsError);
  });
});
```

- [ ] **Step 11: Run the test and verify it fails**

Run: `npm --prefix functions test`
Expected: FAIL — `./generateContent` does not exist yet.

- [ ] **Step 12: Write the minimal implementation**

`functions/src/generateContent.ts`:
```ts
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { callGemini } from "./providers/gemini";
import { callGroq, callOpenRouter } from "./providers/openAiCompatible";
import type { GenerateContentResult } from "./providers/types";

export type AiProvider = "gemini" | "groq" | "openrouter";

export interface GenerateContentRequest {
  provider: AiProvider;
  apiKey: string;
  model: string;
  prompt: string;
}

function isGenerateContentRequest(data: unknown): data is GenerateContentRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    (d.provider === "gemini" || d.provider === "groq" || d.provider === "openrouter") &&
    typeof d.apiKey === "string" &&
    d.apiKey.length > 0 &&
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
      "Expected { provider, apiKey, model, prompt } (all non-empty strings)."
    );
  }

  const { provider, ...params } = request.data;

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
    throw new HttpsError(
      "internal",
      `AI provider call failed: ${err instanceof Error ? err.message : String(err)}`
    );
  }
}

export const generateContent = onCall(generateContentHandler);
```

- [ ] **Step 13: Run the test and verify it passes**

Run: `npm --prefix functions test`
Expected: PASS — all tests passed.

- [ ] **Step 14: Export it from the functions entry point**

Modify `functions/src/index.ts`:
```ts
export { ping } from "./ping";
export { generateContent } from "./generateContent";
```

- [ ] **Step 15: Verify the build compiles**

Run: `npm --prefix functions run build`
Expected: no TypeScript errors.

- [ ] **Step 16: Commit**

```bash
git add functions
git commit -m "feat(functions): add generateContent LLM proxy (Gemini/Groq/OpenRouter)"
```

---

## Task 7: Wire `generateContent` into the Next.js app

**Files:**
- Create: `apps/web/src/lib/generateContent.ts`
- Create: `apps/web/src/lib/generateContent.test.ts`
- Create: `apps/web/src/components/GenerateContentPanel.tsx`
- Create: `apps/web/src/components/GenerateContentPanel.test.tsx`
- Modify: `apps/web/src/app/page.tsx`

**Interfaces:**
- Consumes: `getFirebaseFunctions()` from `apps/web/src/lib/firebase.ts` (Task 3); the request/response shape defined by `functions/src/generateContent.ts` (Task 6) — `{provider, apiKey, model, prompt}` → `{text}`.
- Produces: `apps/web/src/lib/generateContent.ts` exports `AiProvider`, `GenerateContentRequest`, `GenerateContentResult`, `generateContent(request)`.

- [ ] **Step 1: Write the failing test for the client-side `generateContent` wrapper**

`apps/web/src/lib/generateContent.test.ts`:
```ts
import { describe, expect, it, vi } from "vitest";
import { httpsCallable } from "firebase/functions";
import { generateContent } from "./generateContent";

vi.mock("firebase/functions", () => ({
  httpsCallable: vi.fn(),
  getFunctions: vi.fn(),
}));
vi.mock("./firebase", () => ({
  getFirebaseFunctions: vi.fn(() => "mock-functions"),
}));

describe("generateContent", () => {
  it("calls the generateContent callable and returns its data", async () => {
    const mockCallable = vi.fn().mockResolvedValue({ data: { text: "hello" } });
    vi.mocked(httpsCallable).mockReturnValue(mockCallable as never);

    const result = await generateContent({
      provider: "gemini",
      apiKey: "k",
      model: "gemini-2.5-flash",
      prompt: "hi",
    });

    expect(result).toEqual({ text: "hello" });
    expect(httpsCallable).toHaveBeenCalledWith("mock-functions", "generateContent");
    expect(mockCallable).toHaveBeenCalledWith({
      provider: "gemini",
      apiKey: "k",
      model: "gemini-2.5-flash",
      prompt: "hi",
    });
  });
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./generateContent` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

`apps/web/src/lib/generateContent.ts`:
```ts
import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";

export type AiProvider = "gemini" | "groq" | "openrouter";

export interface GenerateContentRequest {
  provider: AiProvider;
  apiKey: string;
  model: string;
  prompt: string;
}

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

- [ ] **Step 4: Run the test and verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Write the failing test for `GenerateContentPanel`**

`apps/web/src/components/GenerateContentPanel.test.tsx`:
```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { GenerateContentPanel } from "./GenerateContentPanel";
import { generateContent } from "@/lib/generateContent";

vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));

describe("GenerateContentPanel", () => {
  it("calls generateContent with the form values and displays the result", async () => {
    vi.mocked(generateContent).mockResolvedValue({ text: "Xin chào!" });
    render(<GenerateContentPanel />);

    fireEvent.change(screen.getByLabelText("API key"), {
      target: { value: "test-key" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Tạo nội dung" }));

    await waitFor(() =>
      expect(screen.getByTestId("generate-content-result")).toHaveTextContent(
        "Xin chào!"
      )
    );
    expect(generateContent).toHaveBeenCalledWith({
      provider: "gemini",
      apiKey: "test-key",
      model: "gemini-2.5-flash",
      prompt: "Say hello in Vietnamese.",
    });
  });

  it("shows an error message when generateContent rejects", async () => {
    vi.mocked(generateContent).mockRejectedValue(new Error("unauthenticated"));
    render(<GenerateContentPanel />);
    fireEvent.click(screen.getByRole("button", { name: "Tạo nội dung" }));
    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent("unauthenticated")
    );
  });
});
```

- [ ] **Step 6: Run the test and verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./GenerateContentPanel` does not exist yet.

- [ ] **Step 7: Write the minimal implementation**

`apps/web/src/components/GenerateContentPanel.tsx`:
```tsx
"use client";

import { useState, type FormEvent } from "react";
import { generateContent, type AiProvider } from "@/lib/generateContent";

export function GenerateContentPanel() {
  const [provider, setProvider] = useState<AiProvider>("gemini");
  const [apiKey, setApiKey] = useState("");
  const [model, setModel] = useState("gemini-2.5-flash");
  const [prompt, setPrompt] = useState("Say hello in Vietnamese.");
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const response = await generateContent({ provider, apiKey, model, prompt });
      setResult(response.text);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={(e) => void handleSubmit(e)}>
      <label>
        Provider
        <select
          value={provider}
          onChange={(e) => setProvider(e.target.value as AiProvider)}
        >
          <option value="gemini">Gemini</option>
          <option value="groq">Groq</option>
          <option value="openrouter">OpenRouter</option>
        </select>
      </label>
      <label>
        API key
        <input
          type="password"
          value={apiKey}
          onChange={(e) => setApiKey(e.target.value)}
        />
      </label>
      <label>
        Model
        <input value={model} onChange={(e) => setModel(e.target.value)} />
      </label>
      <label>
        Prompt
        <textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} />
      </label>
      <button type="submit" disabled={loading}>
        {loading ? "Đang gọi AI…" : "Tạo nội dung"}
      </button>
      {error && <p role="alert">{error}</p>}
      {result && <p data-testid="generate-content-result">{result}</p>}
    </form>
  );
}
```

- [ ] **Step 8: Run the test and verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — all tests passed.

- [ ] **Step 9: Mount `GenerateContentPanel` on the home page**

Modify `apps/web/src/app/page.tsx`:
```tsx
import { SignInButton } from "@/components/SignInButton";
import { VocabRecordCount } from "@/components/VocabRecordCount";
import { GenerateContentPanel } from "@/components/GenerateContentPanel";

export default function HomePage() {
  return (
    <main>
      <h1>LexiCore Web</h1>
      <SignInButton />
      <VocabRecordCount />
      <GenerateContentPanel />
    </main>
  );
}
```

- [ ] **Step 10: Commit**

```bash
git add apps/web
git commit -m "feat(web): wire generateContent LLM proxy into the UI"
```

---

## Task 8: Local emulator wiring, Firebase App Hosting setup, and end-to-end deploy verification

**Files:**
- Modify: `apps/web/src/lib/firebase.ts`
- Modify: `apps/web/.env.local.example`
- Modify: `apps/web/.env.local`

**Interfaces:**
- Consumes: every module from Tasks 1–7.
- Produces: a live, working deployment — the deliverable for this task is verified state (signed-in app, real AI response), not new exported code.

- [ ] **Step 1: Wire the Functions emulator into the client (dev-only)**

Modify `apps/web/src/lib/firebase.ts` — change the `getFirebaseFunctions` export:

Before:
```ts
export function getFirebaseFunctions() {
  return getFunctions(getFirebaseApp());
}
```

After:
```ts
let functionsEmulatorConnected = false;

export function getFirebaseFunctions() {
  const functions = getFunctions(getFirebaseApp());
  if (
    process.env.NEXT_PUBLIC_USE_FUNCTIONS_EMULATOR === "true" &&
    !functionsEmulatorConnected
  ) {
    connectFunctionsEmulator(functions, "127.0.0.1", 5001);
    functionsEmulatorConnected = true;
  }
  return functions;
}
```

Add `connectFunctionsEmulator` to the existing `firebase/functions` import at the top of the file:
```ts
import { connectFunctionsEmulator, getFunctions } from "firebase/functions";
```

- [ ] **Step 2: Add the emulator flag to the env files**

Append to both `apps/web/.env.local.example` and `apps/web/.env.local`:
```
NEXT_PUBLIC_USE_FUNCTIONS_EMULATOR=false
```
(Locally, developers flip this to `true` in their own `.env.local` when running the emulator — `.env.local.example` documents the flag but defaults it off so a plain `npm run dev` talks to the real deployed function.)

- [ ] **Step 3: Run the full test suite one more time on both projects**

Run: `npm --prefix apps/web test && npm --prefix functions test`
Expected: PASS — every test from Tasks 1–7 still passes.

- [ ] **Step 4: Test the emulator locally**

Run in one terminal: `npm --prefix functions run build && firebase emulators:start --only functions`
Expected: emulator UI available at `http://127.0.0.1:4000`, `generateContent` and `ping` listed as loaded functions.

In `apps/web/.env.local`, set `NEXT_PUBLIC_USE_FUNCTIONS_EMULATOR=true`, then in another terminal run: `npm --prefix apps/web run dev`
Expected: app boots at `http://localhost:3000`. Sign in with Google, paste a real Gemini API key (get one free at https://aistudio.google.com/ if needed — same provider setup the existing Flutter app documents in `README.md`) into the API key field, leave provider as Gemini and model as `gemini-2.5-flash`, click "Tạo nội dung". Expected: a real Vietnamese greeting appears where `generate-content-result` renders — this proves the full local chain (Next.js → Functions emulator → real Gemini API) works before touching production infrastructure.

Set `NEXT_PUBLIC_USE_FUNCTIONS_EMULATOR` back to `false` in `apps/web/.env.local` once done.

- [ ] **Step 5: Deploy the Cloud Function to production**

Run: `firebase deploy --only functions --project lexi-core`
Expected: deploy succeeds; output lists `generateContent` and `ping` as deployed 2nd-gen functions.

- [ ] **Step 6: Set up the Firebase App Hosting backend for `apps/web/`**

Run: `firebase init apphosting` from the repo root, and follow the interactive prompts — select the `lexi-core` project, point the root directory at `apps/web`, and connect it to this repo's GitHub remote for git-triggered deploys.

**If the CLI's actual prompts or subcommand names differ from this** (App Hosting is a newer Firebase product and its CLI surface may have moved since this plan was written — see the spec's own hedge on this in `docs/superpowers/specs/2026-08-11-react-web-redesign-design.md` §3.1), follow whatever the live `firebase` CLI presents instead; the goal is a deployed App Hosting backend serving `apps/web/`, not matching this exact command.

Add the same 7 `NEXT_PUBLIC_FIREBASE_*` values from `apps/web/.env.local.example` (§Task 3) as the backend's environment variables (via the CLI prompts or the Firebase Console's App Hosting → your backend → Settings screen), plus `NEXT_PUBLIC_USE_FUNCTIONS_EMULATOR=false`.

Expected: a preview/staging URL is produced (e.g. `https://<backend-id>--lexi-core.<region>.hosted.app`), separate from the still-untouched production `lexi-core.web.app` (Flutter Web).

- [ ] **Step 7: Verify the deployed preview end-to-end**

Visit the preview URL from Step 6. Expected, in order:
1. Page loads, shows "LexiCore Web" heading and a "Đăng nhập với Google" button.
2. Clicking it opens a real Google sign-in popup; after signing in, the button changes to "Đăng xuất (<your name>)".
3. Below it, either "Bạn có N từ trong Ngân hàng từ vựng." (if this Google account already has synced Flutter vocab data) or the same with `N = 0` — either is correct; what matters is **no** "Lỗi đọc Firestore" error appears, proving the client Firestore read succeeded against the real, unmodified security rules.
4. Submitting the `GenerateContentPanel` form with a real provider API key returns real generated text (same manual check as Step 4, now against the production Cloud Function instead of the emulator).

If all four checks pass, this plan's goal is met: the full BYOK LLM proxy chain, Google Sign-In, and client-side Firestore access all work end-to-end on the new stack, with Flutter Web (`lexi-core.web.app`) untouched throughout.

- [ ] **Step 8: Commit**

```bash
git add apps/web
git commit -m "feat(web): wire Functions emulator for local dev, verify end-to-end deploy"
```
