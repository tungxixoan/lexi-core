import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import PracticePage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

function makeRecord(overrides: Partial<VocabRecord>): VocabRecord {
  return {
    id: "id",
    headword: "word",
    inputType: "word",
    ipa: "",
    meaning: "nghĩa",
    examples: ["ví dụ"],
    personalNotes: "",
    topicIds: [],
    targetLanguage: "english",
    cefrLevel: "b1",
    activeContext: "general",
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    nextReviewAt: null,
    sm2Repetitions: 0,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: "",
    synonyms: [],
    ...overrides,
  };
}

describe("PracticePage (setup phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<PracticePage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the matching word count and enables Bắt đầu once records load", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    expect(await screen.findByText("2 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Bắt đầu" })).not.toBeDisabled();
  });

  it("disables Bắt đầu when no word matches the filters", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    expect(await screen.findByText("0 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Bắt đầu" })).toBeDisabled();
  });

  it("filters the preview count by the selected maximum CEFR level", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", cefrLevel: "a1" }),
      makeRecord({ id: "2", cefrLevel: "c1" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    await screen.findByText("2 từ khớp bộ lọc hiện tại.");

    fireEvent.change(screen.getByDisplayValue("Mọi trình độ"), { target: { value: "a1" } });

    expect(await screen.findByText("1 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
  });

  it("leaves the setup screen when Bắt đầu is clicked with matching words", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));

    await waitFor(() =>
      expect(screen.queryByRole("button", { name: "Bắt đầu" })).not.toBeInTheDocument()
    );
  });
});
