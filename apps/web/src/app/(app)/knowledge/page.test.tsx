import { beforeEach, describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor } from "@testing-library/react";
import {
  getKnowledgeNotes,
  restoreStarters,
  seedStartersIfNeeded,
  upsertKnowledgeNote,
} from "@/lib/knowledgeNotes";
import { startersFor } from "@/lib/knowledgeStarters";
import { getVocabRecords } from "@/lib/vocabRecords";
import { noteFixture, renderKnowledgePage } from "@/components/knowledge/testUtils";
import KnowledgePage from "./page";

const pushMock = vi.fn();

vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));
vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/knowledgeNotes", async () => {
  const actual =
    await vi.importActual<typeof import("@/lib/knowledgeNotes")>("@/lib/knowledgeNotes");
  return {
    ...actual,
    getKnowledgeNotes: vi.fn(),
    seedStartersIfNeeded: vi.fn(),
    restoreStarters: vi.fn(),
    upsertKnowledgeNote: vi.fn(),
  };
});
vi.mock("@/lib/knowledgeStarters", () => ({ startersFor: vi.fn(() => []) }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(seedStartersIfNeeded).mockResolvedValue([]);
  vi.mocked(restoreStarters).mockResolvedValue([]);
  vi.mocked(startersFor).mockReturnValue([]);
  vi.mocked(getVocabRecords).mockResolvedValue([]);
  vi.mocked(upsertKnowledgeNote).mockResolvedValue(undefined);
});

describe("KnowledgePage", () => {
  it("shows a group grid with counts", async () => {
    renderKnowledgePage(<KnowledgePage />, {
      notes: [
        noteFixture({ id: "n1", groupId: "en_tenses", title: "Thì hiện tại đơn" }),
        noteFixture({ id: "n2", groupId: "en_tenses", title: "Thì hiện tại hoàn thành" }),
        noteFixture({ id: "n3", groupId: "en_conditionals", title: "Câu điều kiện loại 2" }),
      ],
    });

    expect(await screen.findByText("Thì")).toBeInTheDocument();
    expect(screen.getByText("2")).toBeInTheDocument();
  });

  it("typing in search switches to a filtered flat list", async () => {
    renderKnowledgePage(<KnowledgePage />, {
      notes: [
        noteFixture({ id: "n1", groupId: "en_tenses", title: "Thì hiện tại đơn" }),
        noteFixture({ id: "n3", groupId: "en_conditionals", title: "Câu điều kiện loại 2" }),
      ],
    });

    fireEvent.change(await screen.findByPlaceholderText(/Tìm/), {
      target: { value: "dieu kien" },
    });

    expect(await screen.findByText("Câu điều kiện loại 2")).toBeInTheDocument();
    expect(screen.queryByText("Thì hiện tại đơn")).toBeNull();
  });

  it("Khôi phục ghi chú mẫu calls restoreStarters", async () => {
    renderKnowledgePage(<KnowledgePage />, {
      notes: [noteFixture({ id: "n1", groupId: "en_tenses", title: "Thì hiện tại đơn" })],
    });

    fireEvent.click(await screen.findByRole("button", { name: /Khôi phục/ }));

    await waitFor(() => expect(restoreStarters).toHaveBeenCalled());
    expect(getKnowledgeNotes).toHaveBeenCalledWith("u1", "english");
  });

  it("'+ Nhờ AI soạn' opens the AI-compose modal", async () => {
    renderKnowledgePage(<KnowledgePage />, {
      notes: [noteFixture({ id: "n1", groupId: "en_tenses", title: "Thì hiện tại đơn" })],
    });

    fireEvent.click(await screen.findByRole("button", { name: "+ Nhờ AI soạn" }));

    expect(await screen.findByRole("dialog", { name: "Nhờ AI soạn" })).toBeInTheDocument();
  });

  it("empty-state 'Nhờ AI soạn' opens the AI-compose modal", async () => {
    renderKnowledgePage(<KnowledgePage />, { notes: [] });

    fireEvent.click(await screen.findByRole("button", { name: "Nhờ AI soạn" }));

    expect(await screen.findByRole("dialog", { name: "Nhờ AI soạn" })).toBeInTheDocument();
  });
});
