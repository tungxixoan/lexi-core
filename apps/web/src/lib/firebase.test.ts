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
