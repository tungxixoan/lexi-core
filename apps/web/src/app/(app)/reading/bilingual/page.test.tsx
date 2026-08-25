import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import BilingualReadingPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { getAllUsedVocabIds, getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
import type { SavedReadingExercise } from "@/lib/savedReadingExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import { recordDailyActivity } from "@/lib/dailyActivity";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/dailyActivity", () => ({ recordDailyActivity: vi.fn() }));
vi.mock("@/lib/savedReadingExercises", async () => {
  const actual = await vi.importActual<typeof import("@/lib/savedReadingExercises")>(
    "@/lib/savedReadingExercises"
  );
  return {
    ...actual,
    getAllUsedVocabIds: vi.fn(),
    getRandomSavedExercise: vi.fn(),
    saveReadingExercise: vi.fn(),
  };
});
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const pushMock = vi.fn();
const replaceMock = vi.fn();
let mockSearchParams = new URLSearchParams();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: replaceMock }),
  useSearchParams: () => mockSearchParams,
}));
vi.mock("@/components/shared/VocabSuggestionsSection", () => ({
  VocabSuggestionsSection: ({ text }: { text: string }) => (
    <div data-testid="vocab-suggestions" data-text={text} />
  ),
}));

function setSearchParams(params: Record<string, string>) {
  mockSearchParams = new URLSearchParams(params);
}

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

const SAVED_EXERCISE: SavedReadingExercise = {
  id: "saved-1",
  type: "bilingual",
  passage: {
    sentences: [{ target: "Saved sentence.", vietnamese: "Câu đã lưu.", vocabWords: [] }],
    vocabIds: [],
  },
  generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
  targetLanguage: "english",
  createdAt: "2026-01-01T00:00:00.000Z",
};

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
  setSearchParams({ wordCount: "10", action: "generate" });
  vi.mocked(getAllUsedVocabIds).mockResolvedValue(new Set());
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
  vi.mocked(recordDailyActivity).mockResolvedValue(undefined);
});

describe("BilingualReadingPage (loading phase)", () => {
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

  it("redirects to /reading when the action param is missing", async () => {
    setSearchParams({});
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("redirects to /reading when the action param is invalid", async () => {
    setSearchParams({ action: "bogus" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("auto-generates a passage from the due-prioritized word list on mount", async () => {
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

    await waitFor(() => expect(screen.getByText("Câu 1 / 1")).toBeInTheDocument());
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("word0");
  });

  it("excludes words already used in saved exercises when the word list must be truncated", async () => {
    mockSignedIn();
    const freshRecords = Array.from({ length: 10 }, (_, i) =>
      makeRecord({ id: `fresh-${i}`, headword: `freshword${i}` })
    );
    const usedRecord = makeRecord({ id: "used-1", headword: "usedword" });
    vi.mocked(getVocabRecords).mockResolvedValue([...freshRecords, usedRecord]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getAllUsedVocabIds).mockResolvedValue(new Set(["used-1"]));
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ sentences: [{ target: "A.", vietnamese: "B.", vocabWords: [] }] }),
    });

    render(<BilingualReadingPage />);

    await waitFor(() => expect(generateContent).toHaveBeenCalled());
    expect(getAllUsedVocabIds).toHaveBeenCalledWith("u1");
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    // Default word count (10) truncates 11 matching words down to 10 — the
    // 1 used word must be the one dropped, since all 10 fresh ones are
    // prioritized ahead of it.
    expect(promptArg).not.toContain("usedword");
    expect(promptArg).toContain("freshword0");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
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

    expect(
      await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an explanatory error (not a blank screen) when action=generate matches 0 words in the filtered pool", async () => {
    // Before this feature, the setup screen's own button-gating made this
    // path unreachable in practice. Now the hub does that gating one page
    // load earlier, so a stale/hand-edited URL (e.g. a topicIds filter with
    // no matching words) can land here directly with a 0-word pool.
    setSearchParams({ topicIds: "nonexistent-topic", action: "generate" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    expect(
      await screen.findByText("Không tìm thấy từ vựng nào khớp với bộ lọc đã chọn để tạo bài.")
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI returns no usable sentences, and 'Thử lại' retries the same action", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<BilingualReadingPage />);
    await screen.findByText("AI không trả về đoạn văn hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }] }),
    });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByText("Câu 1 / 1")).toBeInTheDocument());
  });

  it('"Về trang chính" on the loading-error state navigates back to the hub', async () => {
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
    await screen.findByRole("button", { name: "Về trang chính" });
    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('action=existing starts a session directly from a matching saved exercise, without calling the AI', async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue(SAVED_EXERCISE);

    render(<BilingualReadingPage />);

    await waitFor(() => expect(screen.getByText("Câu 1 / 1")).toBeInTheDocument());
    expect(screen.getByText("Câu đã lưu.")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing falls back to AI generation with an inline notice when nothing matches", async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
    // generateContent's mock resolution is held open deliberately (instead of
    // mockResolvedValue, which settles within the same microtask burst as
    // everything upstream of it) so the notice's render commit is
    // observable before the AI fallback completes and the screen moves on
    // to the session phase — otherwise this races and the notice's visible
    // window can close before screen.findByText ever gets to see it.
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<BilingualReadingPage />);

    expect(
      await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
    ).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalled();

    resolveGenerate({
      text: JSON.stringify({ sentences: [{ target: "A.", vietnamese: "B.", vocabWords: [] }] }),
    });
    await waitFor(() => expect(screen.getByText("Câu 1 / 1")).toBeInTheDocument());
  });

  it("action=existing shows an explanatory error (not a blank screen) when nothing matches and there aren't enough live words for the AI fallback", async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue(null);

    render(<BilingualReadingPage />);

    expect(
      await screen.findByText("Hãy lưu ít nhất 5 từ khớp với bộ lọc đã chọn vào Ngân hàng từ vựng. Hiện có 2 từ.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
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

    // "word0" is the only headword referenced via a sentence's vocabWords,
    // so passage.vocabIds resolves to exactly 1 id.
    await waitFor(() => expect(recordDailyActivity).toHaveBeenCalledWith("u1", 1));
  });

  it('shows a "Lưu bài" button for a freshly AI-generated session, and hides it once saved', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(saveReadingExercise).mockResolvedValue("new-saved-id");

    await completeASession();

    const saveButton = screen.getByRole("button", { name: "Lưu bài" });
    fireEvent.click(saveButton);

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
    expect(saveReadingExercise).toHaveBeenCalledWith(
      "u1",
      "bilingual",
      expect.objectContaining({ sentences: expect.any(Array) }),
      expect.objectContaining({ topicIds: [], maxCefr: null, wordCount: 10 }),
      "english"
    );
  });

  it('surfaces a save error via role="alert" and keeps the "Lưu bài" button available to retry', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));

    await completeASession();
    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("network down")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu bài" })).toBeInTheDocument();
  });

  it('hides both "Lưu bài" and the vocab-suggestions section for a reused session', async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "bilingual",
      passage: { sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }], vocabIds: [] },
      generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });

    render(<BilingualReadingPage />);
    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
    expect(screen.queryByTestId("vocab-suggestions")).not.toBeInTheDocument();
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

  it('"Sinh bài mới" replays AI-generation directly (no return to setup) for a "generated" session', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ sentences: [{ target: "New one.", vietnamese: "Bài mới.", vocabWords: [] }] }),
    });

    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(await screen.findByText("Câu 1 / 1")).toBeInTheDocument();
  });

  it('shows a generateError alert on the result phase when "Sinh bài mới" fails to regenerate a "generated" session', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();
    vi.mocked(generateContent).mockRejectedValue(new Error("AI unavailable"));

    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(await screen.findByText("AI unavailable")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("AI unavailable");
    // Stayed on the result phase — the stat cards are still visible and no
    // typing session started, so the error must be visible right here, not
    // silently swallowed by a screen that never renders generateError.
    expect(screen.getByText("Độ chính xác")).toBeInTheDocument();
    expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument();
  });

  it('"Sinh bài mới" shows an explanatory error in place (does not navigate away) for a "reused" session when nothing else matches and there aren\'t enough live words for an AI attempt either', async () => {
    // This exercises the "reused" branch, not "generated" — unlike "Tạo bài
    // luyện", "Lấy bài có sẵn" is never gated by the 5-word rule, so a
    // session can legitimately start in "reused" mode with fewer than 5 live
    // matching words. With the setup phase gone, there is no screen left to
    // "fall back to" — fetchSavedExercise's own generateError branch is the
    // only feedback the user gets, rendered right here on the result phase.
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "bilingual",
      passage: { sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }], vocabIds: [] },
      generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });

    render(<BilingualReadingPage />);
    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    vi.mocked(getRandomSavedExercise).mockResolvedValue(null);

    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(
      await screen.findByText("Hãy lưu ít nhất 5 từ khớp với bộ lọc đã chọn vào Ngân hàng từ vựng. Hiện có 2 từ.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
    expect(pushMock).not.toHaveBeenCalledWith("/reading");
  });

  it('"Sinh bài mới" fetches another saved exercise directly for a "reused" session (no exclusion, since reused sessions have no "Lưu bài" button to set justSavedId)', async () => {
    // The spec's "exclude the just-saved exercise from the next random pick"
    // requirement is implemented in fetchSavedExercise's excludeId param
    // (unit-tested directly in Task 1's getRandomSavedExercise tests) and
    // wired here as `justSavedId ?? undefined`. In practice `justSavedId` can
    // only become non-null via "Lưu bài", which only renders for
    // `sessionMode === "generated"` — and a "generated" session's own "Sinh
    // bài mới" always re-runs handleGenerate() directly, never a random pick.
    // So this exact exclusion never actually fires within a single page visit
    // under the current design; this test documents that reality rather than
    // asserting a false claim about it triggering.
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    const FIRST_SAVED = {
      id: "saved-1",
      type: "bilingual" as const,
      passage: { sentences: [{ target: "First.", vietnamese: "Đầu.", vocabWords: [] }], vocabIds: [] },
      generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
      targetLanguage: "english" as const,
      createdAt: "2026-01-01T00:00:00.000Z",
    };
    vi.mocked(getRandomSavedExercise).mockResolvedValue(FIRST_SAVED);

    render(<BilingualReadingPage />);
    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "First." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();

    const SECOND_SAVED = {
      ...FIRST_SAVED,
      id: "saved-2",
      passage: { sentences: [{ target: "Second.", vietnamese: "Hai.", vocabWords: [] }], vocabIds: [] },
    };
    vi.mocked(getRandomSavedExercise).mockResolvedValue(SECOND_SAVED);

    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(await screen.findByText("Câu 1 / 1")).toBeInTheDocument();
    expect(screen.getByText("Second.")).toBeInTheDocument();
    expect(vi.mocked(getRandomSavedExercise).mock.calls[1][4]).toBeUndefined();
  });

  it('"Sinh bài mới" falls back to AI with the inline notice when a "reused" session finds no other saved match', async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "bilingual",
      passage: { sentences: [{ target: "First.", vietnamese: "Đầu.", vocabWords: [] }], vocabIds: [] },
      generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });

    render(<BilingualReadingPage />);
    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "First." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
    // generateContent's mock resolution is held open deliberately (instead of
    // mockResolvedValue, which settles within the same microtask burst as
    // everything upstream of it) so the notice's render commit is
    // observable before the AI fallback completes and the screen moves on
    // to the session phase — otherwise this races and the notice's visible
    // window can close before screen.findByText ever gets to see it (same
    // pattern as the loading-phase "falls back to AI generation" test above).
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(
      await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
    ).toBeInTheDocument();

    resolveGenerate({
      text: JSON.stringify({ sentences: [{ target: "AI made.", vietnamese: "AI tạo.", vocabWords: [] }] }),
    });
    await waitFor(() => expect(screen.getByText("AI tạo.")).toBeInTheDocument());
  });

  it("clears the stale save error and saved-notice from a prior session once a fresh session's result screen renders", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));

    await completeASession();
    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("network down");

    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ sentences: [{ target: "New one.", vietnamese: "Bài mới.", vocabWords: [] }] }),
    });
    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "New one." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(screen.queryByText(/đang tạo bài mới bằng AI/)).not.toBeInTheDocument();
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
