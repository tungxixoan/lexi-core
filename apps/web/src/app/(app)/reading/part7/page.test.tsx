import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import Part7Page from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import type { Part7Set } from "@/lib/part7";

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
const replaceMock = vi.fn();
let mockSearchParams = new URLSearchParams();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: replaceMock }),
  useSearchParams: () => mockSearchParams,
}));

function setSearchParams(params: Record<string, string>) {
  mockSearchParams = new URLSearchParams(params);
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

// A genuine 3-group / 12-question set: group 0 has 3 questions, group 1 has
// 4, group 2 (double-document) has 5 — deliberately UNEQUAL group sizes so
// the running-sum flatIndex offsets (0, 3, 7) are non-uniform, which a fixed
// multiplier or an off-by-one would fail to reproduce. Every one of the 48
// option strings across the whole fixture is textually unique so every
// getByRole("button", { name }) call below stays unambiguous.
const THREE_GROUP_SET: Part7Set = {
  passageGroups: [
    {
      documents: ["A memo about the new parking policy."],
      questions: [
        {
          question: "What is the memo about?",
          options: ["Parking policy", "Lunch menu", "Holiday schedule", "IT outage"],
          correctIndex: 0,
          explanation: "Nói về chính sách đỗ xe.",
        },
        {
          question: "When does the policy take effect?",
          options: ["Immediately", "Next month", "Next year", "Unknown"],
          correctIndex: 1,
          explanation: "Có hiệu lực tháng sau.",
        },
        {
          question: "Who should employees contact?",
          options: ["Human Resources", "Facilities", "IT Support", "Security Team"],
          correctIndex: 1,
          explanation: "Liên hệ bộ phận Facilities.",
        },
      ],
    },
    {
      documents: ["An email announcing a new product launch."],
      questions: [
        {
          question: "What product is being launched?",
          options: ["A software tool", "A phone", "A chair", "A car"],
          correctIndex: 0,
          explanation: "Ra mắt một công cụ phần mềm.",
        },
        {
          question: "When is the launch date?",
          options: ["Monday", "Tuesday", "Wednesday", "Thursday"],
          correctIndex: 2,
          explanation: "Ra mắt vào thứ Tư.",
        },
        {
          question: "Who is the email from?",
          options: ["CEO", "Marketing Team", "IT Department", "People Ops"],
          correctIndex: 1,
          explanation: "Từ bộ phận Marketing.",
        },
        {
          question: "What is requested of the reader?",
          options: ["Attend a demo", "Buy now", "Ignore it", "Forward it"],
          correctIndex: 0,
          explanation: "Yêu cầu tham dự buổi demo.",
        },
      ],
    },
    {
      documents: [
        "A job advertisement for a marketing manager.",
        "An application email from a candidate.",
      ],
      questions: [
        {
          question: "What position is advertised?",
          options: ["Marketing Manager", "Sales Rep", "Engineer", "Designer"],
          correctIndex: 0,
          explanation: "Vị trí Marketing Manager.",
        },
        {
          question: "What does the candidate attach?",
          options: ["A resume", "A photo", "A video", "Nothing"],
          correctIndex: 0,
          explanation: "Đính kèm sơ yếu lý lịch.",
        },
        {
          question: "How many years of experience does the ad require?",
          options: ["One year", "Three years", "Five years", "Ten years"],
          correctIndex: 2,
          explanation: "Yêu cầu 5 năm kinh nghiệm.",
        },
        {
          question: "What must be true for the candidate to qualify, based on both documents?",
          options: ["Five years experience match", "Wrong location", "No degree", "Too young"],
          correctIndex: 0,
          explanation: "Cần đối chiếu cả 2 văn bản.",
        },
        {
          question: "When does the candidate want to start?",
          options: ["Right away", "In a year", "Never", "Unclear"],
          correctIndex: 0,
          explanation: "Muốn bắt đầu ngay.",
        },
      ],
    },
  ],
};

beforeEach(() => {
  vi.clearAllMocks();
  setSearchParams({ action: "generate" });
  vi.mocked(getVocabRecords).mockResolvedValue([]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
});

describe("Part7Page (loading phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({ settings: null, loading: false, error: null, save: vi.fn() });
    render(<Part7Page />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("redirects to /reading when the action param is missing", async () => {
    setSearchParams({});
    mockSignedIn();

    render(<Part7Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("redirects to /reading when the action param is invalid", async () => {
    setSearchParams({ action: "bogus" });
    mockSignedIn();

    render(<Part7Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("auto-generates a set on mount, resolving topicIds to topic names in the prompt", async () => {
    setSearchParams({ topicIds: "biz-1", action: "generate" });
    mockSignedIn();
    const topics: Topic[] = [{ id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" }];
    vi.mocked(getTopics).mockResolvedValue(topics);
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_GROUP_SET) });

    render(<Part7Page />);

    expect(await screen.findByText("Đoạn 1")).toBeInTheDocument();
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("exactly 3 passage groups");
    expect(promptArg).toContain("Business");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part7Page />);

    expect(await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI response has an invalid shape, and 'Thử lại' retries the same action", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<Part7Page />);
    await screen.findByText("AI không trả về bài luyện hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_GROUP_SET) });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByText("Đoạn 1")).toBeInTheDocument());
  });

  it('"Về trang chính" on the loading-error state navigates back to the hub', async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part7Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('action=existing starts a session directly from a matching saved exercise, without calling the AI', async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part7",
      passage: THREE_GROUP_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    render(<Part7Page />);

    expect(await screen.findByText("Đoạn 1")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing shows an inline notice and falls back to AI generation when nothing matches", async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<Part7Page />);

    expect(await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalled();

    resolveGenerate({ text: JSON.stringify(THREE_GROUP_SET) });
    await waitFor(() => expect(screen.getByText("Đoạn 1")).toBeInTheDocument());
  });
});

describe("Part7Page (session phase)", () => {
  async function generateSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_GROUP_SET) });
    render(<Part7Page />);
    await screen.findByText("Đoạn 1");
  }

  it("renders all 3 groups with their documents, the double-document group labeled distinctly, and questions numbered per group", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByText("Đoạn 1")).toBeInTheDocument();
    expect(screen.getByText("Đoạn 2")).toBeInTheDocument();
    expect(screen.getByText("Đoạn 3 (2 văn bản liên quan)")).toBeInTheDocument();
    expect(screen.getByText("A memo about the new parking policy.")).toBeInTheDocument();
    expect(screen.getByText("A job advertisement for a marketing manager.")).toBeInTheDocument();
    expect(screen.getByText("An application email from a candidate.")).toBeInTheDocument();
    expect(screen.getByText("1. What is the memo about?")).toBeInTheDocument();
    // Question numbering resets per group — group 2's first question is
    // "1. ...", not a running total like "8. ...".
    expect(screen.getByText("1. What position is advertised?")).toBeInTheDocument();
  });

  it("maps cross-group selections to independent slots via the running-sum flatIndex", async () => {
    mockSignedIn();
    await generateSession();

    // flatIndex(0,2) = 2, flatIndex(2,0) = 3+4+0 = 7 — chosen because the
    // group sizes are unequal (3, 4, 5), so a wrong formula (a fixed
    // multiplier, or summing indices instead of prior group lengths) would
    // misalign these two selections onto the same or a different slot than
    // the correct one.
    fireEvent.click(screen.getByRole("button", { name: "Human Resources" })); // group 0, question index 2
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" })); // group 2, question index 0

    expect(screen.getByRole("button", { name: "Human Resources" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: "Marketing Manager" })).toHaveAttribute("aria-pressed", "true");
    // Sibling options in those same two questions must stay unselected.
    expect(screen.getByRole("button", { name: "Facilities" })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "Sales Rep" })).toHaveAttribute("aria-pressed", "false");
    // Every other question's options must be untouched by these two clicks.
    expect(screen.getByRole("button", { name: "Parking policy" })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "Right away" })).toHaveAttribute("aria-pressed", "false");
  });

  it("keeps Nộp bài disabled until all 12 questions across all 3 groups are answered", async () => {
    mockSignedIn();
    await generateSession();

    // Answer 11 of 12, spread across all 3 groups (not clustered in one).
    fireEvent.click(screen.getByRole("button", { name: "Parking policy" }));
    fireEvent.click(screen.getByRole("button", { name: "Next month" }));
    fireEvent.click(screen.getByRole("button", { name: "Facilities" }));
    fireEvent.click(screen.getByRole("button", { name: "A software tool" }));
    fireEvent.click(screen.getByRole("button", { name: "Wednesday" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Team" }));
    fireEvent.click(screen.getByRole("button", { name: "Attend a demo" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" }));
    fireEvent.click(screen.getByRole("button", { name: "A resume" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years experience match" }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Right away" })); // the 12th, final answer
    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();
  });
});

describe("Part7Page (result phase)", () => {
  async function completeSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_GROUP_SET) });
    render(<Part7Page />);
    await screen.findByText("Đoạn 1");
    // Group 0: all 3 correct.
    fireEvent.click(screen.getByRole("button", { name: "Parking policy" }));
    fireEvent.click(screen.getByRole("button", { name: "Next month" }));
    fireEvent.click(screen.getByRole("button", { name: "Facilities" }));
    // Group 1: 2 correct, 2 wrong.
    fireEvent.click(screen.getByRole("button", { name: "A software tool" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "Wednesday" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "CEO" })); // wrong (correct is Marketing Team)
    fireEvent.click(screen.getByRole("button", { name: "Buy now" })); // wrong (correct is Attend a demo)
    // Group 2: 3 correct, 2 wrong.
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "A resume" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "Five years" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "Wrong location" })); // wrong
    fireEvent.click(screen.getByRole("button", { name: "Never" })); // wrong
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText(/\d+\/12/);
  }

  it("scores 8/12 from a deliberate correct/incorrect mix spread across all 3 groups, with explanations", async () => {
    mockSignedIn();
    await completeSession();

    expect(screen.getByText("8/12")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Nói về chính sách đỗ xe.")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Cần đối chiếu cả 2 văn bản.")).toBeInTheDocument();
    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute(
      "data-text",
      "A memo about the new parking policy. An email announcing a new product launch. A job advertisement for a marketing manager. An application email from a candidate."
    );
  });

  it('shows "Lưu bài" for a generated session and saves with the type "part7"', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockResolvedValue("new-id");
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(saveReadingExercise).toHaveBeenCalledWith(
      "u1",
      "part7",
      expect.objectContaining({ passageGroups: expect.any(Array) }),
      expect.objectContaining({ topicIds: [], volumes: [] }),
      "english"
    );
  });

  it('"Bài khác" replays AI-generation directly for a generated session', async () => {
    mockSignedIn();
    await completeSession();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        passageGroups: [
          {
            documents: ["New group document."],
            questions: [
              { question: "New question?", options: ["w", "x", "y", "z"], correctIndex: 0, explanation: "E." },
              { question: "New question 2?", options: ["w2", "x2", "y2", "z2"], correctIndex: 0, explanation: "E." },
              { question: "New question 3?", options: ["w3", "x3", "y3", "z3"], correctIndex: 0, explanation: "E." },
            ],
          },
          {
            documents: ["Second new document."],
            questions: [
              { question: "Q4?", options: ["a4", "b4", "c4", "d4"], correctIndex: 0, explanation: "E." },
              { question: "Q5?", options: ["a5", "b5", "c5", "d5"], correctIndex: 0, explanation: "E." },
              { question: "Q6?", options: ["a6", "b6", "c6", "d6"], correctIndex: 0, explanation: "E." },
            ],
          },
          {
            documents: ["Third doc A.", "Third doc B."],
            questions: Array.from({ length: 5 }, (_, i) => ({
              question: `DQ${i}?`,
              options: [`da${i}`, `db${i}`, `dc${i}`, `dd${i}`],
              correctIndex: 0,
              explanation: "E.",
            })),
          },
        ],
      }),
    });

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("New group document.")).toBeInTheDocument();
  });

  it('"Về trang chính" navigates back to the reading hub', async () => {
    mockSignedIn();
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('surfaces a save error via role="alert" when saveReadingExercise rejects', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("network down")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("network down");
  });

  it("hides the vocab-suggestions section and the Lưu bài button for a reused session's result screen", async () => {
    mockSignedIn();
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part7",
      passage: THREE_GROUP_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part7Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "Parking policy" }));
    fireEvent.click(screen.getByRole("button", { name: "Next month" }));
    fireEvent.click(screen.getByRole("button", { name: "Facilities" }));
    fireEvent.click(screen.getByRole("button", { name: "A software tool" }));
    fireEvent.click(screen.getByRole("button", { name: "Wednesday" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Team" }));
    fireEvent.click(screen.getByRole("button", { name: "Attend a demo" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" }));
    fireEvent.click(screen.getByRole("button", { name: "A resume" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years experience match" }));
    fireEvent.click(screen.getByRole("button", { name: "Right away" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("12/12");

    expect(screen.queryByTestId("vocab-suggestions")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });

  it('"Bài khác" fetches another saved exercise directly for a reused session, not the AI', async () => {
    mockSignedIn();
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-1",
      type: "part7",
      passage: THREE_GROUP_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part7Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "Parking policy" }));
    fireEvent.click(screen.getByRole("button", { name: "Next month" }));
    fireEvent.click(screen.getByRole("button", { name: "Facilities" }));
    fireEvent.click(screen.getByRole("button", { name: "A software tool" }));
    fireEvent.click(screen.getByRole("button", { name: "Wednesday" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Team" }));
    fireEvent.click(screen.getByRole("button", { name: "Attend a demo" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" }));
    fireEvent.click(screen.getByRole("button", { name: "A resume" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years experience match" }));
    fireEvent.click(screen.getByRole("button", { name: "Right away" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("12/12");

    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-2",
      type: "part7",
      passage: {
        passageGroups: [
          {
            documents: ["Another group document."],
            questions: [
              { question: "Another Q?", options: ["p", "q", "r", "s"], correctIndex: 0, explanation: "E." },
              { question: "Another Q2?", options: ["p2", "q2", "r2", "s2"], correctIndex: 0, explanation: "E." },
              { question: "Another Q3?", options: ["p3", "q3", "r3", "s3"], correctIndex: 0, explanation: "E." },
            ],
          },
          {
            documents: ["Second another document."],
            questions: [
              { question: "AQ4?", options: ["p4", "q4", "r4", "s4"], correctIndex: 0, explanation: "E." },
              { question: "AQ5?", options: ["p5", "q5", "r5", "s5"], correctIndex: 0, explanation: "E." },
              { question: "AQ6?", options: ["p6", "q6", "r6", "s6"], correctIndex: 0, explanation: "E." },
            ],
          },
          {
            documents: ["Third another A.", "Third another B."],
            questions: Array.from({ length: 5 }, (_, i) => ({
              question: `ADQ${i}?`,
              options: [`ada${i}`, `adb${i}`, `adc${i}`, `add${i}`],
              correctIndex: 0,
              explanation: "E.",
            })),
          },
        ],
      },
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("Another group document.")).toBeInTheDocument();
    expect(getRandomSavedExercise).toHaveBeenCalledTimes(2);
    expect(generateContent).not.toHaveBeenCalled();
  });
});
