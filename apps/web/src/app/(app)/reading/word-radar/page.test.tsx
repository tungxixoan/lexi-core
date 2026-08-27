import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import WordRadarPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));
vi.mock("@/components/shared/VocabSuggestionsSection", () => ({
  VocabSuggestionsSection: () => <div data-testid="suggestions-section" />,
}));

const SETTINGS_NO_KEY: UserSettings = DEFAULT_SETTINGS;
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

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({
    settings,
    loading: false,
    error: null,
    save: vi.fn(),
  });
  vi.mocked(getTopics).mockResolvedValue([]);
}

beforeEach(() => vi.clearAllMocks());

describe("WordRadarPage (auth)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: null,
      loading: false,
      error: null,
      save: vi.fn(),
    });
    render(<WordRadarPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });
});

describe("WordRadarPage (scan)", () => {
  it("disables Quét until text is entered, and highlights known words after scanning", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "r1", headword: "increase", targetLanguage: "english" }),
    ]);

    render(<WordRadarPage />);
    const scanBtn = await screen.findByRole("button", { name: "Quét" });
    expect(scanBtn).toBeDisabled();

    const textarea = screen.getByPlaceholderText("Dán văn bản vào đây…");
    fireEvent.change(textarea, { target: { value: "A big increase happened." } });
    expect(scanBtn).not.toBeDisabled();

    fireEvent.click(scanBtn);
    expect(screen.getByRole("button", { name: "increase" })).toBeInTheDocument();
  });

  it("excludes known-word records from a different target language", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "r1", headword: "increase", targetLanguage: "chinese" }),
    ]);

    render(<WordRadarPage />);
    const textarea = await screen.findByPlaceholderText("Dán văn bản vào đây…");
    fireEvent.change(textarea, { target: { value: "A big increase happened." } });
    fireEvent.click(screen.getByRole("button", { name: "Quét" }));

    expect(screen.queryByRole("button", { name: "increase" })).not.toBeInTheDocument();
  });

  it("enforces a 3000-character max on the textarea", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<WordRadarPage />);
    const textarea = await screen.findByPlaceholderText("Dán văn bản vào đây…");
    expect(textarea).toHaveAttribute("maxLength", "3000");
  });

  it("shows the suggestions section (AI on) once scanned", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<WordRadarPage />);
    const textarea = await screen.findByPlaceholderText("Dán văn bản vào đây…");
    fireEvent.change(textarea, { target: { value: "Some text." } });
    fireEvent.click(screen.getByRole("button", { name: "Quét" }));
    expect(screen.getByTestId("suggestions-section")).toBeInTheDocument();
  });

  it("shows the AI-disabled hint instead of the suggestions section when AI is off", async () => {
    mockSignedIn(SETTINGS_NO_KEY);
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<WordRadarPage />);
    const textarea = await screen.findByPlaceholderText("Dán văn bản vào đây…");
    fireEvent.change(textarea, { target: { value: "Some text." } });
    fireEvent.click(screen.getByRole("button", { name: "Quét" }));
    expect(screen.getByText("Bật AI trong Cài đặt để nhận gợi ý từ mới.")).toBeInTheDocument();
    expect(screen.queryByTestId("suggestions-section")).not.toBeInTheDocument();
  });
});
