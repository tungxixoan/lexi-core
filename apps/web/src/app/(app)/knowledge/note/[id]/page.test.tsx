import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getKnowledgeNotes } from "@/lib/knowledgeNotes";
import { getVocabRecords } from "@/lib/vocabRecords";
import { DEFAULT_SETTINGS } from "@/lib/settings";
import { noteFixture, renderKnowledgePage } from "@/components/knowledge/testUtils";
import NoteDetailPage from "./page";

vi.mock("next/navigation", () => ({ useRouter: () => ({ push: vi.fn() }) }));
vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/knowledgeNotes", async () => {
  const actual =
    await vi.importActual<typeof import("@/lib/knowledgeNotes")>("@/lib/knowledgeNotes");
  return { ...actual, getKnowledgeNotes: vi.fn() };
});
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

beforeEach(() => vi.clearAllMocks());

describe("KnowledgeNoteDetailPage", () => {
  it("links Sửa to the absolute edit route for this note — the route-level regression test for the broken relative link bug", async () => {
    renderKnowledgePage(<NoteDetailPage params={Promise.resolve({ id: "n1" })} />, {
      notes: [noteFixture({ id: "n1", title: "Câu điều kiện loại 2" })],
    });

    expect(await screen.findByRole("heading", { name: "Câu điều kiện loại 2" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Sửa" })).toHaveAttribute(
      "href",
      "/knowledge/note/n1/edit",
    );
  });

  it("still renders the note when the vocab-bank fetch fails", async () => {
    // Deliberately not using renderKnowledgePage: it unconditionally sets
    // getVocabRecords to mockResolvedValue, which would clobber the
    // rejection this test needs in place before the component's mount
    // effect fires.
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: DEFAULT_SETTINGS,
      loading: false,
      error: null,
      save: vi.fn(),
    } as never);
    vi.mocked(getKnowledgeNotes).mockResolvedValue([
      noteFixture({ id: "n1", title: "Câu điều kiện loại 2" }),
    ]);
    vi.mocked(getVocabRecords).mockRejectedValue(new Error("firestore unavailable"));

    render(<NoteDetailPage params={Promise.resolve({ id: "n1" })} />);

    expect(await screen.findByRole("heading", { name: "Câu điều kiện loại 2" })).toBeInTheDocument();
  });
});
