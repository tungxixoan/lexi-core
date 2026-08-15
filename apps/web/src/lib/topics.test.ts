import { describe, expect, it, vi } from "vitest";
import { getDocs } from "firebase/firestore";
import { getTopics } from "./topics";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  getDocs: vi.fn(),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

const TOPIC = {
  id: "business",
  name: "Business",
  emoji: "💼",
  isPredefined: true,
  createdAt: "2026-01-01T00:00:00.000",
};

describe("getTopics", () => {
  it("returns the user's topics subcollection docs", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      docs: [{ id: TOPIC.id, data: () => TOPIC }],
    } as never);
    const topics = await getTopics("user-123");
    expect(topics).toEqual([TOPIC]);
  });

  it("uses the Firestore snapshot document id, not the id field inside the document data", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        {
          id: "real-doc-id",
          data: () => ({ ...TOPIC, id: "stale-field-id" }),
        },
      ],
    } as never);

    const topics = await getTopics("user-123");

    expect(topics[0].id).toBe("real-doc-id");
  });
});
