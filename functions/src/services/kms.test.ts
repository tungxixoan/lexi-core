import { afterEach, describe, expect, it, vi } from "vitest";

const mockEncrypt = vi.fn();
const mockDecrypt = vi.fn();
const mockCryptoKeyPath = vi.fn(
  (project: string, location: string, keyRing: string, key: string) =>
    `projects/${project}/locations/${location}/keyRings/${keyRing}/cryptoKeys/${key}`
);

vi.mock("@google-cloud/kms", () => {
  const KeyManagementServiceClientClass = class {
    encrypt = mockEncrypt;
    decrypt = mockDecrypt;
    cryptoKeyPath = mockCryptoKeyPath;
  };
  return {
    KeyManagementServiceClient: KeyManagementServiceClientClass,
  };
});

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
    await expect(encryptWithKms("secret", "user-123")).rejects.toThrow(/Cloud KMS configuration/);
  });

  it("encrypts plaintext via the correct key path, binding it to the caller's uid as AAD", async () => {
    stubKmsEnv();
    mockEncrypt.mockResolvedValue([{ ciphertext: Buffer.from("cipherbytes") }]);
    const { encryptWithKms } = await import("./kms");

    const result = await encryptWithKms("my-api-key", "user-123");

    expect(mockCryptoKeyPath).toHaveBeenCalledWith(
      "lexi-core",
      "asia-southeast1",
      "lexicore-keys",
      "byok-api-keys"
    );
    expect(mockEncrypt).toHaveBeenCalledWith({
      name: "projects/lexi-core/locations/asia-southeast1/keyRings/lexicore-keys/cryptoKeys/byok-api-keys",
      plaintext: Buffer.from("my-api-key", "utf8"),
      additionalAuthenticatedData: Buffer.from("user-123", "utf8"),
    });
    expect(result).toBe(Buffer.from("cipherbytes").toString("base64"));
  });

  it("throws when the KMS response has no ciphertext", async () => {
    stubKmsEnv();
    mockEncrypt.mockResolvedValue([{}]);
    const { encryptWithKms } = await import("./kms");
    await expect(encryptWithKms("my-api-key", "user-123")).rejects.toThrow(/no ciphertext/);
  });
});

describe("decryptWithKms", () => {
  it("decrypts base64 ciphertext back to the original plaintext, binding it to the caller's uid as AAD", async () => {
    stubKmsEnv();
    mockDecrypt.mockResolvedValue([{ plaintext: Buffer.from("my-api-key") }]);
    const { decryptWithKms } = await import("./kms");

    const result = await decryptWithKms(Buffer.from("cipherbytes").toString("base64"), "user-123");

    expect(mockDecrypt).toHaveBeenCalledWith({
      name: "projects/lexi-core/locations/asia-southeast1/keyRings/lexicore-keys/cryptoKeys/byok-api-keys",
      ciphertext: Buffer.from("cipherbytes"),
      additionalAuthenticatedData: Buffer.from("user-123", "utf8"),
    });
    expect(result).toBe("my-api-key");
  });

  it("throws when the KMS response has no plaintext", async () => {
    stubKmsEnv();
    mockDecrypt.mockResolvedValue([{}]);
    const { decryptWithKms } = await import("./kms");
    await expect(decryptWithKms("abc", "user-123")).rejects.toThrow(/no plaintext/);
  });
});
