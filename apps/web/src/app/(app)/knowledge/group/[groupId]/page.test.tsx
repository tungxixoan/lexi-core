import { beforeEach, describe, expect, it, vi } from "vitest";
import { screen } from "@testing-library/react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getKnowledgeNotes } from "@/lib/knowledgeNotes";
import { getVocabRecords } from "@/lib/vocabRecords";
import { noteFixture, renderKnowledgePage } from "@/components/knowledge/testUtils";
import GroupPage from "./page";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/knowledgeNotes", () => ({ getKnowledgeNotes: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

beforeEach(() => vi.clearAllMocks());

describe("KnowledgeGroupPage", () => {
  it("sections notes by CEFR", async () => {
    renderKnowledgePage(<GroupPage params={Promise.resolve({ groupId: "en_tenses" })} />, {
      notes: [
        noteFixture({ id: "n1", groupId: "en_tenses", cefrLevel: "a1", title: "Ghi chú A1" }),
        noteFixture({ id: "n2", groupId: "en_tenses", cefrLevel: "b2", title: "Ghi chú B2" }),
        noteFixture({ id: "n3", groupId: "en_tenses", cefrLevel: null, title: "Ghi chú chưa gắn cấp độ" }),
        noteFixture({ id: "n4", groupId: "en_passive", cefrLevel: "a1", title: "Nhóm khác" }),
      ],
    });

    expect(await screen.findByRole("heading", { name: "A1", level: 3 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "B2", level: 3 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Chưa gắn cấp độ", level: 3 })).toBeInTheDocument();
    expect(screen.getByText("Ghi chú A1")).toBeInTheDocument();
    expect(screen.queryByText("Nhóm khác")).toBeNull();
  });

  it("titles the page with the group label", async () => {
    renderKnowledgePage(<GroupPage params={Promise.resolve({ groupId: "en_tenses" })} />, { notes: [] });
    expect(await screen.findByRole("heading", { name: "Thì" })).toBeInTheDocument();
  });

  it("prompts sign-in when logged out", async () => {
    renderKnowledgePage(<GroupPage params={Promise.resolve({ groupId: "en_tenses" })} />, {
      signedIn: false,
    });
    expect(await screen.findByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("fetches notes scoped to the active target language", async () => {
    renderKnowledgePage(<GroupPage params={Promise.resolve({ groupId: "en_tenses" })} />, { notes: [] });
    await screen.findByRole("heading", { name: "Thì" });
    expect(getKnowledgeNotes).toHaveBeenCalledWith("u1", "english");
  });
});
