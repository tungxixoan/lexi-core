import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import Part5Page from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import type { Part5Set } from "@/lib/part5";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/savedReadingExercises", async () => {
  const actual = await vi.importActual<typeof import("@/lib/savedReadingExercises")>("@/lib/savedReadingExercises");
  return {
    ...actual,
    getRandomSavedExercise: vi.fn(),
    saveReadingExercise: vi.fn(),
  };
});
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));
vi.mock("@/components/shared/VocabSuggestionsSection", () => ({
  VocabSuggestionsSection: ({ text }: { text: string }) => <div data-testid="vocab-suggestions" data-text={text} />,
}));

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini",
  providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" } },
};

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

const ONE_QUESTION_SET: Part5Set = {
  questions: [{ sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "Ngôi thứ ba số ít." }],
};

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(getVocabRecords).mockResolvedValue([]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
});

describe("Part5Page (setup phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({ settings: null, loading: false, error: null, save: vi.fn() });
    render(<Part5Page />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows both action buttons enabled with no words/context precondition", async () => {
    mockSignedIn();
    render(<Part5Page />);
    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });

  it("generates a set and enters the session phase", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_QUESTION_SET) });

    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(await screen.findByText("1. She ___ to work.")).toBeInTheDocument();
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("exactly 15");
  });

  it("shows an error and stays on setup when the active provider has no API key", async () => {
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error and stays on setup when the AI returns no usable questions", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify({}) });

    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(await screen.findByText("AI không trả về bài luyện hợp lệ.")).toBeInTheDocument();
  });

  it('"Lấy bài có sẵn" starts a session directly from a matching saved exercise, without calling the AI', async () => {
    mockSignedIn();
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part5",
      passage: ONE_QUESTION_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(await screen.findByText("1. She ___ to work.")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it('"Lấy bài có sẵn" shows an inline notice and falls back to AI generation when nothing matches', async () => {
    mockSignedIn();
    // generateContent's mock resolution is held open deliberately (instead of
    // mockResolvedValue, which settles within the same microtask burst as
    // everything upstream of it) so the notice's render commit is
    // observable before the AI fallback completes and the screen moves on
    // to the session phase — otherwise this races and the notice's visible
    // window can close before screen.findByText ever gets to see it (same
    // pattern as bilingual/page.test.tsx).
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalled();

    resolveGenerate({ text: JSON.stringify(ONE_QUESTION_SET) });
    await waitFor(() => expect(screen.getByText("1. She ___ to work.")).toBeInTheDocument());
  });
});

describe("Part5Page (session phase)", () => {
  async function generateSession() {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        questions: [
          { sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "A." },
          { sentenceWithBlank: "They ___ happy.", options: ["is", "am", "are", "be"], correctIndex: 2, explanation: "B." },
        ],
      }),
    });
    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("1. She ___ to work.");
  }

  it("keeps Nộp bài disabled until every question has an answer, then submits into the result phase", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "goes" }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "are" }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));

    expect(await screen.findByText("2/2")).toBeInTheDocument();
  });
});

describe("Part5Page (result phase)", () => {
  async function completeSession(answers: number[]) {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        questions: [
          { sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "Giải thích A." },
        ],
      }),
    });
    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("1. She ___ to work.");
    fireEvent.click(screen.getByRole("button", { name: ["go", "goes", "going", "gone"][answers[0]] }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText(/\d\/\d/);
  }

  it("shows the score, per-question breakdown with explanation, and the suggestions section", async () => {
    mockSignedIn();
    await completeSession([1]);

    expect(screen.getByText("1/1")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Giải thích A.")).toBeInTheDocument();
    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute("data-text", "She ___ to work.");
  });

  it('shows "Lưu bài" for a generated session and saves with the type "part5"', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockResolvedValue("new-id");
    await completeSession([1]);

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(saveReadingExercise).toHaveBeenCalledWith(
      "u1",
      "part5",
      expect.objectContaining({ questions: expect.any(Array) }),
      expect.objectContaining({ topicIds: [], volumes: [] }),
      "english"
    );
  });

  it('"Bài khác" replays AI-generation directly for a generated session', async () => {
    mockSignedIn();
    await completeSession([1]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ questions: [{ sentenceWithBlank: "New one.", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." }] }),
    });

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("1. New one.")).toBeInTheDocument();
  });

  it('"Về trang chính" navigates back to the reading hub', async () => {
    mockSignedIn();
    await completeSession([1]);

    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('surfaces a save error via role="alert" when saveReadingExercise rejects', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));
    await completeSession([1]);

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("network down")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("network down");
  });

  async function completeReusedSession() {
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part5",
      passage: ONE_QUESTION_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));
    await screen.findByText("1. She ___ to work.");
    fireEvent.click(screen.getByRole("button", { name: "goes" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("1/1");
  }

  it("hides the vocab-suggestions section and the Lưu bài button for a reused session's result screen", async () => {
    mockSignedIn();
    await completeReusedSession();

    expect(screen.queryByTestId("vocab-suggestions")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });

  it('"Bài khác" fetches another saved exercise directly for a reused session, not the AI', async () => {
    mockSignedIn();
    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-1",
      type: "part5",
      passage: ONE_QUESTION_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));
    await screen.findByText("1. She ___ to work.");
    fireEvent.click(screen.getByRole("button", { name: "goes" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("1/1");

    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-2",
      type: "part5",
      passage: {
        questions: [{ sentenceWithBlank: "New saved one.", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." }],
      },
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("1. New saved one.")).toBeInTheDocument();
    expect(getRandomSavedExercise).toHaveBeenCalledTimes(2);
    expect(generateContent).not.toHaveBeenCalled();
  });
});
