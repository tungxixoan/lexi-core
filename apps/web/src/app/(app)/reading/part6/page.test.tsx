import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import Part6Page from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import type { Part6Set } from "@/lib/part6";
import { recordDailyActivity } from "@/lib/dailyActivity";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/dailyActivity", () => ({ recordDailyActivity: vi.fn() }));
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

const ONE_PASSAGE_SET: Part6Set = {
  passages: [
    {
      passageText: "Please arrive (1)___ 9am.",
      questions: [
        { options: ["before", "after", "during", "since"], correctIndex: 0, explanation: "Trước 9h." },
        { options: ["employee", "employees", "employee's", "employees'"], correctIndex: 0, explanation: "Danh từ ghép." },
        {
          options: [
            "Please sign in at the front desk.",
            "The weather is nice today.",
            "We sell many products.",
            "Coffee is available.",
          ],
          correctIndex: 0,
          explanation: "Câu phù hợp nhất.",
        },
        { options: ["for come", "for coming", "to coming", "come"], correctIndex: 1, explanation: "Giới từ + V-ing." },
      ],
    },
  ],
};

// A genuine 3-passage set (12 blanks total) — every option string across all
// 12 blanks is unique so getByRole("button", { name }) calls stay
// unambiguous. This exists specifically to exercise flatIndex's
// passageIndex * QUESTIONS_PER_PASSAGE + questionIndex mapping across
// multiple passages: ONE_PASSAGE_SET above (passageIndex always 0) can't
// distinguish a correct formula from a broken one like `passageIndex +
// questionIndex` or `passageIndex * questionIndex`, since with a single
// passage almost any formula degenerates to the same flat index.
const THREE_PASSAGE_SET: Part6Set = {
  passages: [
    {
      passageText:
        "Employees must move (1)___ during the fire drill. All (2)___ should assemble outside immediately. " +
        "(3)___ (4)___ everyone waits calmly for the all-clear signal.",
      questions: [
        { options: ["swiftly", "slowly", "loudly", "softly"], correctIndex: 0, explanation: "Trạng từ chỉ cách thức." },
        { options: ["managers", "manager", "management", "managerial"], correctIndex: 1, explanation: "Danh từ số ít." },
        {
          options: [
            "Please sign in at the front desk.",
            "The kitchen closes at noon.",
            "Visitors must wear a badge.",
            "Parking is available nearby.",
          ],
          correctIndex: 0,
          explanation: "Câu phù hợp nhất với ngữ cảnh.",
        },
        { options: ["in order to", "so that", "even though", "as long as"], correctIndex: 2, explanation: "Liên từ nhượng bộ." },
      ],
    },
    {
      passageText:
        "The (1)___ arrived late due to bad weather. Customers found the courier service very (2)___ overall. " +
        "(3)___ (4)___ the delayed delivery, we issued a partial refund.",
      questions: [
        { options: ["shipment", "shipments", "shipping", "shipped"], correctIndex: 0, explanation: "Danh từ số ít." },
        { options: ["reliable", "reliably", "reliability", "relying"], correctIndex: 2, explanation: "Danh từ trừu tượng." },
        {
          options: [
            "The invoice is attached below.",
            "Our office relocated last year.",
            "Staff meetings are held weekly.",
            "Refunds take five business days.",
          ],
          correctIndex: 3,
          explanation: "Câu phù hợp nhất với ngữ cảnh.",
        },
        { options: ["despite", "although", "because", "unless"], correctIndex: 1, explanation: "Liên từ nhượng bộ." },
      ],
    },
    {
      passageText:
        "The office (1)___ project begins next Monday morning. Workers must move (2)___ to finish before the deadline. " +
        "(3)___ (4)___ completion, staff will return to their usual desks.",
      questions: [
        { options: ["renovation", "renovate", "renovated", "renovating"], correctIndex: 0, explanation: "Danh từ số ít." },
        { options: ["quickly", "quicker", "quickest", "quick"], correctIndex: 0, explanation: "Trạng từ chỉ cách thức." },
        {
          options: [
            "The new policy takes effect Monday.",
            "Lunch will be provided at noon.",
            "The conference room is booked.",
            "Employees should submit forms early.",
          ],
          correctIndex: 2,
          explanation: "Câu phù hợp nhất với ngữ cảnh.",
        },
        { options: ["provided that", "in spite of", "as a result", "prior to"], correctIndex: 3, explanation: "Cụm giới từ." },
      ],
    },
  ],
};

async function generateThreePassageSession() {
  setSearchParams({ action: "generate" });
  vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_PASSAGE_SET) });
  render(<Part6Page />);
  await screen.findByText("Đoạn 1");
}

beforeEach(() => {
  vi.clearAllMocks();
  setSearchParams({ action: "generate" });
  vi.mocked(getVocabRecords).mockResolvedValue([]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
  vi.mocked(recordDailyActivity).mockResolvedValue(undefined);
});

describe("Part6Page (loading phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({ settings: null, loading: false, error: null, save: vi.fn() });
    render(<Part6Page />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("redirects to /reading when the action param is missing", async () => {
    setSearchParams({});
    mockSignedIn();

    render(<Part6Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("redirects to /reading when the action param is invalid", async () => {
    setSearchParams({ action: "bogus" });
    mockSignedIn();

    render(<Part6Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("auto-generates a set on mount, resolving topicIds to topic names in the prompt", async () => {
    setSearchParams({ topicIds: "biz-1", action: "generate" });
    mockSignedIn();
    const topics: Topic[] = [{ id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" }];
    vi.mocked(getTopics).mockResolvedValue(topics);
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_PASSAGE_SET) });

    render(<Part6Page />);

    expect(await screen.findByText("Đoạn 1")).toBeInTheDocument();
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("exactly 3");
    expect(promptArg).toContain("Business");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part6Page />);

    expect(await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI returns no usable passages, and 'Thử lại' retries the same action", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<Part6Page />);
    await screen.findByText("AI không trả về bài luyện hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_PASSAGE_SET) });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByText("Đoạn 1")).toBeInTheDocument());
  });

  it('"Về trang chính" on the loading-error state navigates back to the hub', async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part6Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('action=existing starts a session directly from a matching saved exercise, without calling the AI', async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part6",
      passage: ONE_PASSAGE_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    render(<Part6Page />);

    expect(await screen.findByText("Đoạn 1")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing shows an inline notice and falls back to AI generation when nothing matches", async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    // generateContent's mock resolution is held open deliberately (instead of
    // mockResolvedValue, which settles within the same microtask burst as
    // everything upstream of it) so the notice's render commit is
    // observable before the AI fallback completes and the screen moves on
    // to the session phase — same pattern as part5/page.test.tsx.
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<Part6Page />);

    expect(await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalled();

    resolveGenerate({ text: JSON.stringify(ONE_PASSAGE_SET) });
    await waitFor(() => expect(screen.getByText("Đoạn 1")).toBeInTheDocument());
  });
});

describe("Part6Page (session phase)", () => {
  async function generateSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_PASSAGE_SET) });
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");
  }

  it("shows the passage text and 4 blank groups labeled Chỗ trống (1)-(4)", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByText("Please arrive (1)___ 9am.")).toBeInTheDocument();
    expect(screen.getByText("Chỗ trống (1)")).toBeInTheDocument();
    expect(screen.getByText("Chỗ trống (2)")).toBeInTheDocument();
    expect(screen.getByText("Chỗ trống (3)")).toBeInTheDocument();
    expect(screen.getByText("Chỗ trống (4)")).toBeInTheDocument();
  });

  it("keeps Nộp bài disabled until every blank has an answer, then submits into the result phase", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "before" }));
    fireEvent.click(screen.getByRole("button", { name: "employee" }));
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "for coming" }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));

    expect(await screen.findByText("4/4")).toBeInTheDocument();
  });

  it("renders all 3 passages, each with its own 4 blank groups (12 total)", async () => {
    mockSignedIn();
    await generateThreePassageSession();

    expect(screen.getByText("Đoạn 1")).toBeInTheDocument();
    expect(screen.getByText("Đoạn 2")).toBeInTheDocument();
    expect(screen.getByText("Đoạn 3")).toBeInTheDocument();

    for (const label of ["Chỗ trống (1)", "Chỗ trống (2)", "Chỗ trống (3)", "Chỗ trống (4)"]) {
      expect(screen.getAllByText(label)).toHaveLength(3);
    }
    expect(screen.getAllByText(/^Chỗ trống \(\d\)$/)).toHaveLength(12);
  });

  it("maps cross-passage selections to independent slots via flatIndex, without touching other blanks", async () => {
    mockSignedIn();
    await generateThreePassageSession();

    // Select passage 2's blank 3 and passage 3's blank 1. Under the correct
    // flatIndex(p, q) = p * 4 + q formula these land at flat slots 6 and 8,
    // touching nothing else. A broken formula like `p + q` collides
    // flatIndex(1, 2) with flatIndex(0, 3) (both = 3), and `p * q` collides
    // flatIndex(1, 2) with flatIndex(2, 1) and flatIndex(2, 0) with every
    // passage-1 blank (p = 0) — any of those would surface as a stray
    // "pressed" option below on a blank we never clicked.
    fireEvent.click(screen.getByRole("button", { name: "Staff meetings are held weekly." })); // passage 2, blank 3
    fireEvent.click(screen.getByRole("button", { name: "renovate" })); // passage 3, blank 1

    expect(screen.getByRole("button", { name: "Staff meetings are held weekly." })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: "The invoice is attached below." })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "Our office relocated last year." })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "Refunds take five business days." })).toHaveAttribute("aria-pressed", "false");

    expect(screen.getByRole("button", { name: "renovate" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: "renovation" })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "renovated" })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "renovating" })).toHaveAttribute("aria-pressed", "false");

    // Blanks that would falsely light up under a `p + q` or `p * q` formula
    // (see comment above) — must all remain unselected.
    expect(screen.getByRole("button", { name: "even though" })).toHaveAttribute("aria-pressed", "false"); // passage 1, blank 4
    expect(screen.getByRole("button", { name: "The kitchen closes at noon." })).toHaveAttribute("aria-pressed", "false"); // passage 1, blank 3
    expect(screen.getByRole("button", { name: "reliably" })).toHaveAttribute("aria-pressed", "false"); // passage 2, blank 2

    // Untouched blanks in general stay unselected too.
    expect(screen.getByRole("button", { name: "swiftly" })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "quickly" })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "prior to" })).toHaveAttribute("aria-pressed", "false");

    // Only 2 of 12 slots are answered — submit stays disabled.
    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
  });

  it("keeps Nộp bài disabled until all 12 blanks across all 3 passages are answered", async () => {
    mockSignedIn();
    await generateThreePassageSession();

    fireEvent.click(screen.getByRole("button", { name: "swiftly" })); // passage 1, blank 1
    fireEvent.click(screen.getByRole("button", { name: "managers" })); // passage 1, blank 2
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." })); // passage 1, blank 3
    fireEvent.click(screen.getByRole("button", { name: "in order to" })); // passage 1, blank 4
    fireEvent.click(screen.getByRole("button", { name: "shipment" })); // passage 2, blank 1
    fireEvent.click(screen.getByRole("button", { name: "reliable" })); // passage 2, blank 2
    fireEvent.click(screen.getByRole("button", { name: "The invoice is attached below." })); // passage 2, blank 3
    fireEvent.click(screen.getByRole("button", { name: "despite" })); // passage 2, blank 4
    fireEvent.click(screen.getByRole("button", { name: "renovation" })); // passage 3, blank 1
    fireEvent.click(screen.getByRole("button", { name: "quickly" })); // passage 3, blank 2
    fireEvent.click(screen.getByRole("button", { name: "The new policy takes effect Monday." })); // passage 3, blank 3

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "provided that" })); // passage 3, blank 4 (the 12th)

    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();
  });
});

describe("Part6Page (result phase)", () => {
  async function completeSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_PASSAGE_SET) });
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "before" }));
    fireEvent.click(screen.getByRole("button", { name: "employee" }));
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." }));
    fireEvent.click(screen.getByRole("button", { name: "for coming" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText(/\d\/\d/);
  }

  it("scores answers spread across all 3 passages independently", async () => {
    mockSignedIn();
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_PASSAGE_SET) });
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");

    // Passage 1: correct, correct, WRONG, correct → 3/4
    fireEvent.click(screen.getByRole("button", { name: "swiftly" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "manager" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "The kitchen closes at noon." })); // wrong (correct is index 0)
    fireEvent.click(screen.getByRole("button", { name: "even though" })); // correct

    // Passage 2: WRONG, correct, correct, WRONG → 2/4
    fireEvent.click(screen.getByRole("button", { name: "shipped" })); // wrong (correct is index 0)
    fireEvent.click(screen.getByRole("button", { name: "reliability" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "Refunds take five business days." })); // correct
    fireEvent.click(screen.getByRole("button", { name: "despite" })); // wrong (correct is index 1, "although")

    // Passage 3: correct, WRONG, correct, correct → 3/4
    fireEvent.click(screen.getByRole("button", { name: "renovation" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "quickest" })); // wrong (correct is index 0, "quickly")
    fireEvent.click(screen.getByRole("button", { name: "The conference room is booked." })); // correct
    fireEvent.click(screen.getByRole("button", { name: "prior to" })); // correct

    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));

    // 3 + 2 + 3 = 8 correct out of 12, spread across all 3 passages.
    expect(await screen.findByText("8/12")).toBeInTheDocument();
  });

  it("shows the score, per-blank breakdown with explanation, and the suggestions section", async () => {
    mockSignedIn();
    await completeSession();

    expect(screen.getByText("4/4")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Trước 9h.")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Giới từ + V-ing.")).toBeInTheDocument();
    await waitFor(() => expect(recordDailyActivity).toHaveBeenCalledWith("u1", 4));
    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute("data-text", "Please arrive (1)___ 9am.");
  });

  it('shows "Lưu bài" for a generated session and saves with the type "part6"', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockResolvedValue("new-id");
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(saveReadingExercise).toHaveBeenCalledWith(
      "u1",
      "part6",
      expect.objectContaining({ passages: expect.any(Array) }),
      expect.objectContaining({ topicIds: [], volumes: [] }),
      "english"
    );
  });

  it('"Bài khác" replays AI-generation directly for a generated session', async () => {
    mockSignedIn();
    await completeSession();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        passages: [
          {
            passageText: "New passage.",
            questions: [
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
            ],
          },
        ],
      }),
    });

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("New passage.")).toBeInTheDocument();
  });

  it('"Về trang chính" navigates back to the reading hub', async () => {
    mockSignedIn();
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('records daily activity again after completing a second session in place via "Bài khác" (dailyActivityRecordedRef must reset, not just fire once per page load)', async () => {
    mockSignedIn();
    await completeSession();
    await waitFor(() => expect(recordDailyActivity).toHaveBeenCalledTimes(1));
    expect(recordDailyActivity).toHaveBeenCalledWith("u1", 4);

    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        passages: [
          {
            passageText: "New passage.",
            questions: [
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
            ],
          },
        ],
      }),
    });
    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));
    await screen.findByText("New passage.");
    for (const button of screen.getAllByRole("button", { name: "a" })) {
      fireEvent.click(button);
    }
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("4/4");

    await waitFor(() => expect(recordDailyActivity).toHaveBeenCalledTimes(2));
  });

  it('surfaces a save error via role="alert" when saveReadingExercise rejects', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("network down")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("network down");
  });

  async function completeReusedSession() {
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part6",
      passage: ONE_PASSAGE_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "before" }));
    fireEvent.click(screen.getByRole("button", { name: "employee" }));
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." }));
    fireEvent.click(screen.getByRole("button", { name: "for coming" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("4/4");
  }

  it("hides the vocab-suggestions section and the Lưu bài button for a reused session's result screen", async () => {
    mockSignedIn();
    await completeReusedSession();

    expect(screen.queryByTestId("vocab-suggestions")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });

  it('"Bài khác" fetches another saved exercise directly for a reused session, not the AI', async () => {
    mockSignedIn();
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-1",
      type: "part6",
      passage: ONE_PASSAGE_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "before" }));
    fireEvent.click(screen.getByRole("button", { name: "employee" }));
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." }));
    fireEvent.click(screen.getByRole("button", { name: "for coming" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("4/4");

    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-2",
      type: "part6",
      passage: {
        passages: [
          {
            passageText: "New saved one.",
            questions: [
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
            ],
          },
        ],
      },
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("New saved one.")).toBeInTheDocument();
    expect(getRandomSavedExercise).toHaveBeenCalledTimes(2);
    expect(generateContent).not.toHaveBeenCalled();
  });
});
