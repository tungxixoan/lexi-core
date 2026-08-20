import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import BilingualReadingPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini",
  providers: {
    ...DEFAULT_SETTINGS.providers,
    gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" },
  },
};

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

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({
    settings,
    loading: false,
    error: null,
    save: vi.fn(),
  });
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe("BilingualReadingPage (setup phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: null,
      loading: false,
      error: null,
      save: vi.fn(),
    });
    render(<BilingualReadingPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the minimum-words hint instead of the generate button when fewer than 5 words match", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1" }),
      makeRecord({ id: "2" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    expect(
      await screen.findByText("Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có 2 từ.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
  });

  it("shows the generate button once at least 5 words match", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
  });

  it("generates a passage from the due-prioritized word list and leaves the setup screen", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [{ target: "A sentence.", vietnamese: "Một câu.", vocabWords: ["word0"] }],
      }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    await waitFor(() =>
      expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument()
    );
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("word0");
  });

  it("shows an error and stays on setup when the active provider has no API key", async () => {
    mockSignedIn({
      ...DEFAULT_SETTINGS,
      activeProvider: "gemini",
      providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } },
    });
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(
      await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error and stays on setup when the AI returns no usable sentences", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify({}) });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(await screen.findByText("AI không trả về đoạn văn hợp lệ.")).toBeInTheDocument();
    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).toBeInTheDocument();
  });
});
