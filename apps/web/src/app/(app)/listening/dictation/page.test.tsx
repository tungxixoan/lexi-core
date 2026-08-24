import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import DictationPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, updateVocabRecordSm2, type VocabRecord } from "@/lib/vocabRecords";
import { generateContent } from "@/lib/generateContent";
import { synthesizeSpeech } from "@/lib/synthesizeSpeechClient";
import { getRandomSavedListeningExercise, saveListeningExercise } from "@/lib/savedListeningExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn(), updateVocabRecordSm2: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/synthesizeSpeechClient", async () => {
  const actual = await vi.importActual<typeof import("@/lib/synthesizeSpeechClient")>("@/lib/synthesizeSpeechClient");
  return { ...actual, synthesizeSpeech: vi.fn() };
});
vi.mock("@/lib/savedListeningExercises", () => ({
  getRandomSavedListeningExercise: vi.fn(),
  saveListeningExercise: vi.fn(),
}));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const RealAudio = window.Audio;
let audioInstances: HTMLAudioElement[];

const pushMock = vi.fn();
const replaceMock = vi.fn();
let mockSearchParams = new URLSearchParams();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: replaceMock }),
  useSearchParams: () => mockSearchParams,
}));

function setSearchParams(params: Record<string, string>) {
  mockSearchParams = new URLSearchParams(params);
}

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

const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini",
  providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" } },
};

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

const TWO_WORDS = [
  makeRecord({ id: "v1", headword: "apple" }),
  makeRecord({ id: "v2", headword: "run" }),
];

beforeEach(() => {
  vi.clearAllMocks();
  setSearchParams({ difficulty: "hard", action: "generate" });
  vi.mocked(getVocabRecords).mockResolvedValue(TWO_WORDS);
  vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
  vi.mocked(getRandomSavedListeningExercise).mockResolvedValue(null);

  audioInstances = [];
  vi.spyOn(window, "Audio").mockImplementation(function () {
    const el = new RealAudio();
    audioInstances.push(el);
    return el as unknown as HTMLAudioElement;
  } as unknown as typeof Audio);
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("DictationPage (language gate)", () => {
  it("renders the same gate message as the hub and never runs session logic when targetLanguage is not english", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: { ...SETTINGS_WITH_KEY, targetLanguage: "japanese" },
      loading: false,
      error: null,
      save: vi.fn(),
    });

    render(<DictationPage />);

    expect(
      await screen.findByText(
        "Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng."
      )
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
    expect(synthesizeSpeech).not.toHaveBeenCalled();
  });
});

describe("DictationPage (loading phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({ settings: null, loading: false, error: null, save: vi.fn() });
    render(<DictationPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("redirects to /listening when the action param is missing", async () => {
    setSearchParams({ difficulty: "hard" });
    mockSignedIn();

    render(<DictationPage />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/listening"));
  });

  it("redirects to /listening when the action param is invalid", async () => {
    setSearchParams({ difficulty: "hard", action: "bogus" });
    mockSignedIn();

    render(<DictationPage />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/listening"));
  });

  it("auto-generates a sentence from the 2 due-prioritized words on mount", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ target: "I ate an apple.", vietnamese: "Tôi đã ăn một quả táo.", vocabWords: ["apple"] }),
    });

    render(<DictationPage />);

    expect(await screen.findByRole("button", { name: "▶ Phát" })).toBeInTheDocument();
    // Both fixture words have nextReviewAt: null (both "due"), so
    // prioritizeDueWords' internal shuffle can place them in either order —
    // assert both are present rather than asserting one exact order.
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("apple");
    expect(promptArg).toContain("run");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<DictationPage />);

    expect(await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an explanatory error when fewer than 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "v1" })]);

    render(<DictationPage />);

    expect(
      await screen.findByText("Hãy lưu ít nhất 2 từ tiếng Anh vào Ngân hàng từ vựng. Hiện có 1 từ.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI returns an empty sentence, and 'Thử lại' retries the same action", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<DictationPage />);
    await screen.findByText("AI không trả về câu luyện hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ target: "I ate an apple.", vietnamese: "V.", vocabWords: ["apple"] }),
    });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Phát" })).toBeInTheDocument());
  });

  it("action=existing starts a session directly from a matching saved exercise, without calling the AI", async () => {
    setSearchParams({ difficulty: "hard", action: "existing" });
    mockSignedIn();
    vi.mocked(getRandomSavedListeningExercise).mockResolvedValue({
      id: "saved-1",
      type: "dictation",
      item: { target: "I ate an apple.", vietnamese: "V.", vocabIds: ["v1"] },
      generationFilters: { difficulty: "hard" },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });

    render(<DictationPage />);

    expect(await screen.findByRole("button", { name: "▶ Phát" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing falls back to AI generation with an inline notice when nothing matches", async () => {
    setSearchParams({ difficulty: "hard", action: "existing" });
    mockSignedIn();
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<DictationPage />);

    expect(
      await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
    ).toBeInTheDocument();

    resolveGenerate({ text: JSON.stringify({ target: "I ate an apple.", vietnamese: "V.", vocabWords: ["apple"] }) });
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Phát" })).toBeInTheDocument());
  });
});

describe("DictationPage (session phase — Khó / free text)", () => {
  async function generateSession() {
    setSearchParams({ difficulty: "hard", action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ target: "I ate an apple today.", vietnamese: "Tôi đã ăn một quả táo hôm nay.", vocabWords: ["apple"] }),
    });
    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });
  }

  it("keeps Nộp bài disabled until the sentence has been played at least once", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "I ate an apple today.", language: "en" }));
  });

  it("still keeps Nộp bài disabled after playing once, until the textarea has text", async () => {
    mockSignedIn();
    await generateSession();
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();

    fireEvent.change(screen.getByPlaceholderText("Gõ lại những gì bạn nghe được..."), {
      target: { value: "I ate an apple today." },
    });

    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();
  });

  it("does not call seekTo/synthesizeSpeech while dragging the seek slider — only on release, with the last-dragged value", async () => {
    mockSignedIn();
    await generateSession();

    const slider = screen.getByLabelText("Tua theo từ");
    // generateSession() already let the background prefetch fire once for
    // the full sentence — baseline against that instead of assuming 0 calls.
    const baseline = vi.mocked(synthesizeSpeech).mock.calls.length;
    // Simulate a drag across several intermediate positions.
    fireEvent.change(slider, { target: { value: "1" } });
    fireEvent.change(slider, { target: { value: "2" } });
    fireEvent.change(slider, { target: { value: "4" } });
    expect(synthesizeSpeech).toHaveBeenCalledTimes(baseline);

    fireEvent.mouseUp(slider);

    // words = ["I", "ate", "an", "apple", "today."] — index 4 -> remainder "today."
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(baseline + 1));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "today.", language: "en" });
  });

  it("seeks on touch-drag release and on keyboard-arrow release, not on every intermediate onChange", async () => {
    mockSignedIn();
    await generateSession();

    const slider = screen.getByLabelText("Tua theo từ");
    // generateSession() already let the background prefetch fire once for
    // the full sentence — baseline against that instead of assuming 0 calls.
    const baseline = vi.mocked(synthesizeSpeech).mock.calls.length;
    fireEvent.change(slider, { target: { value: "3" } });
    expect(synthesizeSpeech).toHaveBeenCalledTimes(baseline);
    fireEvent.touchEnd(slider);
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(baseline + 1));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "apple today.", language: "en" });
    // seekTo(3) also updates audio.estimatedWordIndex, which the live-tracking
    // sync effect (added in this task) picks up — but that effect's own React
    // commit can lag behind the synthesizeSpeech assertion above by one more
    // microtask/effect-flush cycle in this test environment. Without this
    // extra flush, the pending sync-effect run can land *after* the next
    // fireEvent.change below and stomp it back to the old estimatedWordIndex.
    await waitFor(() => {});

    vi.mocked(synthesizeSpeech).mockClear();
    fireEvent.change(slider, { target: { value: "0" } });
    expect(synthesizeSpeech).not.toHaveBeenCalled();
    fireEvent.keyUp(slider);
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(1));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "I ate an apple today.", language: "en" });
  });

  it("disables the seek slider while audio is loading", async () => {
    mockSignedIn();

    // Set the pending mock up before the session renders, so the background
    // prefetch (which fires on mount, as soon as the sentence is ready) is
    // itself the in-flight request that play() then awaits and stays
    // loading on — rather than a fresh request racing an already-finished
    // prefetch.
    let resolveSpeech!: (value: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockReturnValue(
      new Promise((resolve) => {
        resolveSpeech = resolve;
      })
    );

    await generateSession();

    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByLabelText("Tua theo từ")).toBeDisabled());

    resolveSpeech({ audioBase64: "AAAA" });
    await waitFor(() => expect(screen.getByLabelText("Tua theo từ")).not.toBeDisabled());
  });

  it("the seek slider tracks audio.estimatedWordIndex while the user is not dragging", async () => {
    mockSignedIn();
    await generateSession();

    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());

    const audioEl = audioInstances[audioInstances.length - 1];
    const slider = screen.getByLabelText("Tua theo từ") as HTMLInputElement;

    // words = ["I", "ate", "an", "apple", "today."] — 5 words
    Object.defineProperty(audioEl, "duration", { value: 5, configurable: true });
    Object.defineProperty(audioEl, "currentTime", { value: 2, configurable: true });
    fireEvent(audioEl, new Event("timeupdate"));

    await waitFor(() => expect(slider.value).toBe("2"));
  });

  it("does not let the live-tracking playhead overwrite the slider while the user is dragging", async () => {
    mockSignedIn();
    await generateSession();

    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());

    const audioEl = audioInstances[audioInstances.length - 1];
    const slider = screen.getByLabelText("Tua theo từ") as HTMLInputElement;

    fireEvent.mouseDown(slider);
    fireEvent.change(slider, { target: { value: "1" } });
    expect(slider.value).toBe("1");

    // Simulate playback progress arriving mid-drag — must not fight the user.
    Object.defineProperty(audioEl, "duration", { value: 5, configurable: true });
    Object.defineProperty(audioEl, "currentTime", { value: 4, configurable: true });
    fireEvent(audioEl, new Event("timeupdate"));

    expect(slider.value).toBe("1");

    fireEvent.mouseUp(slider);
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "ate an apple today.", language: "en" }));
  });

  it("the speed slider applies every onChange tick immediately, not gated to release", async () => {
    mockSignedIn();
    await generateSession();

    const speedSlider = screen.getByLabelText("Tốc độ phát") as HTMLInputElement;
    expect(speedSlider.value).toBe("1");
    expect(screen.getByText("1.00x")).toBeInTheDocument();

    fireEvent.change(speedSlider, { target: { value: "1.5" } });

    expect(screen.getByText("1.50x")).toBeInTheDocument();
  });
});

describe("DictationPage (session phase — Dễ/Trung bình / cloze)", () => {
  it("renders inline blank inputs instead of a free-text box for non-hard difficulty", async () => {
    mockSignedIn();
    setSearchParams({ difficulty: "easy", action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ target: "I ate an apple today.", vietnamese: "V.", vocabWords: ["apple"] }),
    });

    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });

    expect(screen.getByLabelText("Chỗ trống 1")).toBeInTheDocument();
    expect(screen.queryByPlaceholderText("Gõ lại những gì bạn nghe được...")).not.toBeInTheDocument();
  });
});

describe("DictationPage (result phase)", () => {
  async function completeHardSession() {
    setSearchParams({ difficulty: "hard", action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        target: "I ate an apple today.",
        vietnamese: "Tôi đã ăn một quả táo hôm nay.",
        vocabWords: ["apple", "run"],
      }),
    });
    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());
    fireEvent.change(screen.getByPlaceholderText("Gõ lại những gì bạn nghe được..."), {
      target: { value: "I ate an apple today." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("100%");
  }

  it("shows the score, correct sentence, meaning, and character diff for a Khó session", async () => {
    mockSignedIn();
    await completeHardSession();

    expect(screen.getByText("100%")).toBeInTheDocument();
    expect(screen.getByText("I ate an apple today.")).toBeInTheDocument();
    expect(screen.getByText("Tôi đã ăn một quả táo hôm nay.")).toBeInTheDocument();
    expect(screen.getByTestId("diff-text")).toBeInTheDocument();
  });

  it("updates SM-2 for both vocab words used, best-effort", async () => {
    mockSignedIn();
    await completeHardSession();

    await waitFor(() => expect(updateVocabRecordSm2).toHaveBeenCalledWith("u1", "v2", expect.any(Object)));
  });

  it('shows "Lưu bài" for a generated session and saves with type "dictation"', async () => {
    mockSignedIn();
    vi.mocked(saveListeningExercise).mockResolvedValue("new-id");
    await completeHardSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(saveListeningExercise).toHaveBeenCalledWith(
      "u1",
      expect.objectContaining({ target: "I ate an apple today." }),
      { difficulty: "hard" },
      "english"
    );
  });

  it('"Về trang chính" navigates back to the listening hub', async () => {
    mockSignedIn();
    await completeHardSession();

    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/listening");
  });

  it("hides the Lưu bài button for a reused session's result screen", async () => {
    mockSignedIn();
    setSearchParams({ difficulty: "hard", action: "existing" });
    vi.mocked(getRandomSavedListeningExercise).mockResolvedValue({
      id: "saved-1",
      type: "dictation",
      item: { target: "I ate an apple today.", vietnamese: "V.", vocabIds: ["v1"] },
      generationFilters: { difficulty: "hard" },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });
    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());
    fireEvent.change(screen.getByPlaceholderText("Gõ lại những gì bạn nghe được..."), {
      target: { value: "I ate an apple today." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("100%");

    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });
});

describe("DictationPage (local records refreshed after SM-2 write)", () => {
  async function completeHardSession() {
    setSearchParams({ difficulty: "hard", action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        target: "I ate an apple today.",
        vietnamese: "Tôi đã ăn một quả táo hôm nay.",
        vocabWords: ["apple", "run"],
      }),
    });
    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());
    fireEvent.change(screen.getByPlaceholderText("Gõ lại những gì bạn nghe được..."), {
      target: { value: "I ate an apple today." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("100%");
  }

  it("a second same-visit session computes SM-2 from the just-updated snapshot, not the stale pre-session records", async () => {
    mockSignedIn();
    await completeHardSession();

    // v1 (apple) and v2 (run) both start at repetitions:0 -> a 100% (quality
    // 5) session bumps them to repetitions:1, interval:1.
    await waitFor(() => expect(updateVocabRecordSm2).toHaveBeenCalledTimes(2));
    expect(updateVocabRecordSm2).toHaveBeenNthCalledWith(
      1,
      "u1",
      "v1",
      expect.objectContaining({ sm2Repetitions: 1, sm2Interval: 1 })
    );
    expect(updateVocabRecordSm2).toHaveBeenNthCalledWith(
      2,
      "u1",
      "v2",
      expect.objectContaining({ sm2Repetitions: 1, sm2Interval: 1 })
    );

    // "Câu khác" starts a second session (same generated mode) within the
    // same page visit — this must reuse the updated in-memory records, not
    // the pre-session fetch from mount.
    fireEvent.click(screen.getByRole("button", { name: "Câu khác" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Phát" })).toBeInTheDocument());
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());
    fireEvent.change(screen.getByPlaceholderText("Gõ lại những gì bạn nghe được..."), {
      target: { value: "I ate an apple today." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("100%");

    // Without the fix, computeSm2 would run again from repetitions:0 and
    // produce repetitions:1/interval:1 a second time. With the fix, it
    // runs from the merged repetitions:1 snapshot -> repetitions:2/interval:6.
    await waitFor(() => expect(updateVocabRecordSm2).toHaveBeenCalledTimes(4));
    expect(updateVocabRecordSm2).toHaveBeenNthCalledWith(
      3,
      "u1",
      "v1",
      expect.objectContaining({ sm2Repetitions: 2, sm2Interval: 6 })
    );
    expect(updateVocabRecordSm2).toHaveBeenNthCalledWith(
      4,
      "u1",
      "v2",
      expect.objectContaining({ sm2Repetitions: 2, sm2Interval: 6 })
    );
  });
});
