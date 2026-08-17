import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import LookupPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecordByHeadword, saveVocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecordByHeadword: vi.fn(), saveVocabRecord: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini" as const,
  providers: {
    ...DEFAULT_SETTINGS.providers,
    gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" },
  },
};

beforeEach(() => {
  vi.clearAllMocks();
});

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

describe("LookupPage", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: null,
      loading: false,
      error: null,
      save: vi.fn(),
    });
    render(<LookupPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the cached Vocab Bank record instantly, with no AI call, when the headword is already saved", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue({
      id: "existing-1",
      headword: "meticulous",
      inputType: "word",
      ipa: "/məˈtɪkjələs/",
      meaning: "tỉ mỉ, cẩn thận",
      examples: ["She is meticulous."],
      personalNotes: "",
      topicIds: [],
      targetLanguage: "english",
      cefrLevel: "c1",
      activeContext: "general",
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-01T00:00:00.000Z",
      nextReviewAt: null,
      sm2Repetitions: 0,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      definition: "",
      synonyms: [],
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByText("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(screen.getByText(/đã có trong Ngân hàng từ vựng/)).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("calls generateContent with the active provider/model/ciphertext when not cached, and displays the parsed result", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        headword: "meticulous",
        ipa: "/məˈtɪkjələs/",
        meaning: "tỉ mỉ, cẩn thận",
        definition: "Showing great attention to detail.",
        synonyms: ["thorough"],
        examples: ["She is meticulous."],
        suggestedTopics: ["Business"],
        cefrLevel: "C1",
      }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    await waitFor(() =>
      expect(generateContent).toHaveBeenCalledWith({
        provider: "gemini",
        model: "gemini-2.5-flash",
        apiKeyCiphertext: "cipher-abc",
        prompt: expect.stringContaining('"meticulous"'),
      })
    );
    expect(await screen.findByText("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(screen.getByText("Showing great attention to detail.")).toBeInTheDocument();
    expect(screen.getByText("thorough")).toBeInTheDocument();
  });

  it("shows a sentence result as translation-only, with no 'already saved' or save affordance", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ translation: "Xin chào thế giới." }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "Hello world." } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByText("Xin chào thế giới.")).toBeInTheDocument();
    expect(getVocabRecordByHeadword).not.toHaveBeenCalled();
    expect(screen.queryByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ })).not.toBeInTheDocument();
  });

  it("shows a helpful message instead of calling the AI when the active provider has no API key saved", async () => {
    mockSignedIn({
      ...DEFAULT_SETTINGS,
      providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } },
    });
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Cài đặt");
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an alert when the AI call fails", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockRejectedValue(new Error("unavailable"));

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("unavailable"));
  });

  it("shows a Lưu button for a fresh word/phrase result", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ headword: "meticulous", meaning: "tỉ mỉ" }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ })).toBeInTheDocument();
  });

  it("does not show a Lưu button for an already-saved word/phrase result", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue({
      id: "existing-1",
      headword: "meticulous",
      inputType: "word",
      ipa: "/məˈtɪkjələs/",
      meaning: "tỉ mỉ, cẩn thận",
      examples: ["She is meticulous."],
      personalNotes: "",
      topicIds: [],
      targetLanguage: "english",
      cefrLevel: "c1",
      activeContext: "general",
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-01T00:00:00.000Z",
      nextReviewAt: null,
      sm2Repetitions: 0,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      definition: "",
      synonyms: [],
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByText(/đã có trong Ngân hàng từ vựng/)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ })).not.toBeInTheDocument();
  });

  it("opens EditVocabModal in create mode when Lưu is clicked, and saves via saveVocabRecord", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        headword: "meticulous",
        ipa: "/məˈtɪkjələs/",
        meaning: "tỉ mỉ, cẩn thận",
        examples: ["She is meticulous."],
        cefrLevel: "C1",
      }),
    });
    vi.mocked(saveVocabRecord).mockResolvedValue("new-id");

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));
    fireEvent.click(await screen.findByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ }));

    expect(screen.getByRole("dialog", { name: /Lưu từ meticulous/ })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(saveVocabRecord).toHaveBeenCalledWith(
        "u1",
        expect.objectContaining({
          headword: "meticulous",
          ipa: "/məˈtɪkjələs/",
          meaning: "tỉ mỉ, cẩn thận",
          examples: ["She is meticulous."],
          cefrLevel: "c1",
          targetLanguage: "english",
          activeContext: "general",
          topicIds: [],
          personalNotes: "",
        })
      )
    );
  });

  it("pre-selects a suggested topic that matches an existing topic name (case-insensitive), capped at 2", async () => {
    mockSignedIn();
    vi.mocked(getTopics).mockResolvedValue([
      { id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
    ]);
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        headword: "meticulous",
        meaning: "tỉ mỉ",
        suggestedTopics: ["business"],
      }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));
    fireEvent.click(await screen.findByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ }));

    expect(screen.getByRole("button", { name: "Business" })).toHaveClass("active");
  });

  it("pre-selects a suggested topic despite punctuation/wording differences from the AI", async () => {
    mockSignedIn();
    vi.mocked(getTopics).mockResolvedValue([
      { id: "food-1", name: "Food & Drink", emoji: "🍜", isPredefined: true, createdAt: "2026-01-01" },
    ]);
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        headword: "savory",
        meaning: "đậm đà",
        suggestedTopics: ["food and drink"],
      }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "savory" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));
    fireEvent.click(await screen.findByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ }));

    expect(screen.getByRole("button", { name: "Food & Drink" })).toHaveClass("active");
  });

  it("does not preselect the same topic twice when the AI suggests it under two different names", async () => {
    mockSignedIn();
    vi.mocked(getTopics).mockResolvedValue([
      { id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
      { id: "tech-1", name: "Technology", emoji: "💻", isPredefined: true, createdAt: "2026-01-01" },
    ]);
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        headword: "synergy",
        meaning: "hợp lực",
        suggestedTopics: ["Business", "business", "Technology"],
      }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "synergy" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));
    fireEvent.click(await screen.findByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ }));

    expect(screen.getByRole("button", { name: "Business" })).toHaveClass("active");
    expect(screen.getByRole("button", { name: "Technology" })).toHaveClass("active");
  });
});

describe("LookupPage (Khám phá từ mới)", () => {
  it("asks the AI for a word and its full entry in a single call, fills the search box", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValueOnce({
      text: JSON.stringify({ headword: "ephemeral", meaning: "phù du" }),
    });

    render(<LookupPage />);
    fireEvent.click(screen.getByRole("button", { name: /Khám phá/ }));

    expect(await screen.findByText("ephemeral")).toBeInTheDocument();
    expect(screen.getByText("phù du")).toBeInTheDocument();
    expect(screen.getByRole("textbox")).toHaveValue("ephemeral");
    expect(generateContent).toHaveBeenCalledTimes(1);
    expect(getVocabRecordByHeadword).toHaveBeenCalledWith("u1", "ephemeral", "english");
  });

  it("shows the cached record with no wasted save-modal state when the discovered word is already saved", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({
      text: JSON.stringify({ headword: "meticulous", meaning: "tỉ mỉ" }),
    });
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue({
      id: "existing-1",
      headword: "meticulous",
      inputType: "word",
      ipa: "",
      meaning: "tỉ mỉ",
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
    });

    render(<LookupPage />);
    fireEvent.click(screen.getByRole("button", { name: /Khám phá/ }));

    expect(await screen.findByText("Từ này đã có trong Ngân hàng từ vựng của bạn.")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalledTimes(1);
  });

  it("shows an error when the AI response has no usable headword", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<LookupPage />);
    fireEvent.click(screen.getByRole("button", { name: /Khám phá/ }));

    expect(await screen.findByRole("alert")).toHaveTextContent("AI không trả về từ hợp lệ.");
    expect(generateContent).toHaveBeenCalledTimes(1);
  });
});
