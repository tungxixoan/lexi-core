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
  it("shows a blocking message and no cards when the target language isn't English", async () => {
    mockSignedIn({ ...DEFAULT_SETTINGS, targetLanguage: "korean" });
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);

    expect(
      await screen.findByText("Nghe hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.")
    ).toBeInTheDocument();
    expect(screen.queryByText("🎤 Nghe chép")).not.toBeInTheDocument();
    expect(screen.queryByText("🎧 Nghe hiểu")).not.toBeInTheDocument();
  });
});

describe("ListeningHubPage (cards)", () => {
  it("renders both mode cards, with no filter row or action buttons until one is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<ListeningHubPage />);

    expect(await screen.findByText("🎤 Nghe chép")).toBeInTheDocument();
    expect(screen.getByText("🎧 Nghe hiểu")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeInTheDocument();
  });

  it("shows the difficulty filter only when the dictation card is selected", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<ListeningHubPage />);

    fireEvent.click(await screen.findByText("🎤 Nghe chép"));
    expect(screen.getByText("Khó")).toBeInTheDocument();
    expect(screen.queryByText(/General/)).not.toBeInTheDocument();
  });

  it("shows the topic/level filters only when the comprehension card is selected", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<ListeningHubPage />);

    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));
    expect(screen.getByText(/General/)).toBeInTheDocument();
    expect(screen.queryByText("Khó")).not.toBeInTheDocument();
  });
});

describe("ListeningHubPage (dictation word gating)", () => {
  it("shows the min-words hint instead of Tạo bài luyện when fewer than 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));

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
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));

    expect(await screen.findByText(/Hiện có 1 từ\./)).toBeInTheDocument();
  });

  it("shows Tạo bài luyện once at least 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
  });

  it("'Lấy bài có sẵn' is never gated by word count, even with 0 eligible words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });
});

describe("ListeningHubPage (comprehension is never gated on vocab count)", () => {
  it("always shows Tạo bài luyện for comprehension, even with 0 vocab records", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
  });
});

describe("ListeningHubPage (navigation)", () => {
  it("dictation defaults to difficulty=hard and navigates with action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/dictation?difficulty=hard&action=generate");
  });

  it("dictation navigates with the selected difficulty and action=existing", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));
    fireEvent.click(screen.getByRole("button", { name: "Dễ" }));
    fireEvent.click(screen.getByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/dictation?difficulty=easy&action=existing");
  });

  it("comprehension defaults to context=general, level omitted (defaults to b1 on the destination page), and navigates with action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/comprehension?context=general&action=generate");
  });

  it("comprehension navigates with the selected context and action=existing, omitting level ('Tất cả') entirely rather than coercing to b1", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));
    fireEvent.click(screen.getByText(/Business/));
    fireEvent.click(screen.getByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/comprehension?context=business&action=existing");
  });

  it("comprehension includes level in the query string once a specific level is picked from the dropdown", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));
    fireEvent.click(screen.getByRole("button", { name: "Tất cả ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "C1" }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/comprehension?context=general&level=c1&action=generate");
  });
});
