import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import ListeningHubPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

function makeRecord(overrides: Partial<VocabRecord>): VocabRecord {
  return {
    id: "id",
    headword: "word",
    inputType: "word",
    ipa: "",
    meaning: "nghĩa",
    examples: [],
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

function mockSignedIn(settings: UserSettings = DEFAULT_SETTINGS) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

beforeEach(() => {
  vi.clearAllMocks();
  // Default mock for useSettingsContext (will be overridden in specific tests)
  vi.mocked(useSettingsContext).mockReturnValue({ settings: DEFAULT_SETTINGS, loading: false, error: null, save: vi.fn() } as never);
});

describe("ListeningHubPage (auth)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<ListeningHubPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });
});

describe("ListeningHubPage (language gate)", () => {
  it("shows a blocking message and no action buttons when the target language isn't English", async () => {
    mockSignedIn({ ...DEFAULT_SETTINGS, targetLanguage: "korean" });
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);

    expect(
      await screen.findByText("Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeInTheDocument();
  });
});

describe("ListeningHubPage (word gating)", () => {
  it("shows the min-words hint instead of Tạo bài luyện when fewer than 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);

    render(<ListeningHubPage />);

    expect(
      await screen.findByText("Hãy lưu ít nhất 2 từ tiếng Anh vào Ngân hàng từ vựng. Hiện có 1 từ.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
  });

  it("only counts words whose targetLanguage is english toward the minimum", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", targetLanguage: "english" }),
      makeRecord({ id: "2", targetLanguage: "korean" }),
    ]);

    render(<ListeningHubPage />);

    expect(await screen.findByText(/Hiện có 1 từ\./)).toBeInTheDocument();
  });

  it("shows Tạo bài luyện once at least 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ListeningHubPage />);

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
  });

  it("'Lấy bài có sẵn' is never gated by word count, even with 0 eligible words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });
});

describe("ListeningHubPage (navigation)", () => {
  it("defaults to difficulty=hard and navigates with action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/dictation?difficulty=hard&action=generate");
  });

  it("navigates with the selected difficulty and action=existing", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Dễ" }));
    fireEvent.click(screen.getByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/dictation?difficulty=easy&action=existing");
  });
});
