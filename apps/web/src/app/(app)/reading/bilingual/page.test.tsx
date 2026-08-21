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

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));
vi.mock("@/components/shared/VocabSuggestionsSection", () => ({
  VocabSuggestionsSection: ({ text }: { text: string }) => (
    <div data-testid="vocab-suggestions" data-text={text} />
  ),
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

describe("BilingualReadingPage (typing session)", () => {
  it("shows the current sentence's progress and Vietnamese translation, advancing on exact match", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [
          { target: "Hi.", vietnamese: "Chào.", vocabWords: [] },
          { target: "Bye.", vietnamese: "Tạm biệt.", vocabWords: [] },
        ],
      }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(await screen.findByText("Câu 1 / 2")).toBeInTheDocument();
    expect(screen.getByText("Chào.")).toBeInTheDocument();

    const input = screen.getByTestId("reading-type-input");
    fireEvent.change(input, { target: { value: "Hi." } });

    expect(await screen.findByText("Câu 2 / 2")).toBeInTheDocument();
    expect(screen.getByText("Tạm biệt.")).toBeInTheDocument();
    expect(screen.getByTestId("reading-type-input")).toHaveValue("");
  });

  it("transitions past the session UI once the last sentence is typed correctly", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }] }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("Câu 1 / 1");

    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi." } });

    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());
  });

  it("does not advance while the typed value only partially matches the target", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [
          { target: "Hi there.", vietnamese: "Chào bạn.", vocabWords: [] },
          { target: "Bye.", vietnamese: "Tạm biệt.", vocabWords: [] },
        ],
      }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("Câu 1 / 2");

    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi " } });

    expect(screen.getByText("Câu 1 / 2")).toBeInTheDocument();
  });
});

describe("BilingualReadingPage (result phase)", () => {
  async function completeASession() {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [
          { target: "Hi there.", vietnamese: "Chào bạn.", vocabWords: ["word0"] },
          { target: "Bye now.", vietnamese: "Tạm biệt.", vocabWords: [] },
        ],
      }),
    });
    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("Câu 1 / 2");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi there." } });
    await screen.findByText("Câu 2 / 2");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Bye now." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());
  }

  it("shows 4 stat cards, the vocab words used, and the suggestions section", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();

    expect(screen.getByText("Độ chính xác")).toBeInTheDocument();
    expect(screen.getByText("Tốc độ")).toBeInTheDocument();
    expect(screen.getByText("Thời gian")).toBeInTheDocument();
    expect(screen.getByText("Điểm")).toBeInTheDocument();
    expect(screen.getAllByText("100%")).toHaveLength(2); // accuracy AND score, both 100%

    expect(screen.getByText(/word0/)).toBeInTheDocument();

    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute("data-text", "Hi there. Bye now.");
  });

  it("shows the full passage and its Vietnamese translation, highlighting the vocab words used", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [
          { target: "I saw a cat today.", vietnamese: "Tôi thấy một con mèo hôm nay.", vocabWords: ["cat"] },
          { target: "It was calm.", vietnamese: "Nó rất bình tĩnh.", vocabWords: [] },
        ],
      }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("Câu 1 / 2");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "I saw a cat today." } });
    await screen.findByText("Câu 2 / 2");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "It was calm." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    expect(screen.getByText(/I saw a/)).toBeInTheDocument();
    expect(screen.getByText(/It was calm\./)).toBeInTheDocument();
    expect(
      screen.getByText("Tôi thấy một con mèo hôm nay. Nó rất bình tĩnh.")
    ).toBeInTheDocument();

    const highlighted = screen.getByText("cat");
    expect(highlighted.tagName).toBe("MARK");
    expect(highlighted).toHaveClass("reading-vocab-highlight");
  });

  it("reflects an in-progress typo (typed wrong, then corrected) in the accuracy card, not just the deletion penalty", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }],
      }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("Câu 1 / 1");

    const input = screen.getByTestId("reading-type-input");
    // Type "Hx." (mismatch at index 1), then correct it to "Hi." without ever
    // deleting — mistakeChars should still capture the wrong keystroke that
    // was overwritten in place (length stayed the same, so deletedChars is 0).
    fireEvent.change(input, { target: { value: "Hx." } });
    fireEvent.change(input, { target: { value: "Hi." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    // 1 mistakeChar out of 3 totalChars -> 1 - 1/3 = 67% (rounded), not 100%.
    expect(screen.getByText("67%")).toBeInTheDocument();
  });

  it('"Sinh bài mới" resets and returns to the setup phase with filters still selected', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();
    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).toBeInTheDocument();
  });

  it('"Về trang chính" navigates back to the reading hub', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();
    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });
});
