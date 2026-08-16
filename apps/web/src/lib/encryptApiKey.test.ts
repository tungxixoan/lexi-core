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
