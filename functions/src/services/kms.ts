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
