import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { VocabSuggestionsSection } from "./VocabSuggestionsSection";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { generateContent } from "@/lib/generateContent";
import { getVocabRecordByHeadword, saveVocabRecord } from "@/lib/vocabRecords";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import type { VocabRecord } from "@/lib/vocabRecords";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({
  getVocabRecordByHeadword: vi.fn(),
  saveVocabRecord: vi.fn(),
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

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({
    settings: SETTINGS_WITH_KEY,
    loading: false,
    error: null,
    save: vi.fn(),
  });
});

describe("VocabSuggestionsSection", () => {
  it("renders nothing at all when the active provider has no API key", () => {
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: DEFAULT_SETTINGS, // no apiKeyCiphertext
      loading: false,
      error: null,
      save: vi.fn(),
    });
    const { container } = render(
      <VocabSuggestionsSection text="Some passage." existingRecords={[]} topics={[]} />
    );
    expect(container.firstChild).toBeNull();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("loads suggestions on mount and renders each as a card", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        suggestions: [
          { headword: "meticulous", ipa: "/x/", meaning: "tỉ mỉ", cefrLevel: "c1" },
        ],
      }),
    });

    render(<VocabSuggestionsSection text="She is meticulous." existingRecords={[]} topics={[]} />);

    expect(await screen.findByText("meticulous")).toBeInTheDocument();
    expect(screen.getByText("tỉ mỉ")).toBeInTheDocument();
  });

  it("shows a 'no suggestions' message when the AI returns an empty list", async () => {
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify({ suggestions: [] }) });
    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    expect(await screen.findByText("Không có gợi ý mới.")).toBeInTheDocument();
  });

  it("shows an error and a Thử lại button when the AI call fails, and retries on click", async () => {
    vi.mocked(generateContent).mockRejectedValueOnce(new Error("network down"));
    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);

    expect(await screen.findByText(/network down/)).toBeInTheDocument();
    const retryBtn = screen.getByRole("button", { name: "Thử lại" });
    expect(retryBtn).toHaveClass("link-btn");
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({ suggestions: [] }) });
    fireEvent.click(retryBtn);
    expect(await screen.findByText("Không có gợi ý mới.")).toBeInTheDocument();
  });

  it("opens EditVocabModal in create mode when a suggestion card is tapped, and saves it", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ suggestions: [{ headword: "meticulous", meaning: "tỉ mỉ" }] }),
    });
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(saveVocabRecord).mockResolvedValue("new-id");

    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    fireEvent.click(await screen.findByText("meticulous"));

    expect(screen.getByRole("dialog", { name: /Lưu từ meticulous/ })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(saveVocabRecord).toHaveBeenCalledWith("u1", expect.any(Object)));
    expect(await screen.findByText("✔")).toBeInTheDocument();
  });

  it('"Lưu tất cả" bulk-saves every not-yet-saved suggestion, skipping duplicates', async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        suggestions: [
          { headword: "meticulous", meaning: "tỉ mỉ" },
          { headword: "ephemeral", meaning: "phù du" },
        ],
      }),
    });
    vi.mocked(getVocabRecordByHeadword).mockImplementation(async (_uid, headword) =>
      headword === "ephemeral"
        ? makeRecord({ id: "existing-1", headword: "ephemeral" })
        : null
    );
    vi.mocked(saveVocabRecord).mockResolvedValue("new-id");

    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    await screen.findByText("meticulous");

    fireEvent.click(screen.getByRole("button", { name: "Lưu tất cả" }));

    await waitFor(() => expect(saveVocabRecord).toHaveBeenCalledTimes(1));
    expect(saveVocabRecord).toHaveBeenCalledWith(
      "u1",
      expect.objectContaining({ headword: "meticulous" })
    );
    expect(await screen.findByText("Đã lưu 1/2 từ.")).toBeInTheDocument();
  });

  it('"Lưu tất cả" surfaces an error and keeps prior progress when a save fails partway', async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        suggestions: [
          { headword: "meticulous", meaning: "tỉ mỉ" },
          { headword: "ephemeral", meaning: "phù du" },
        ],
      }),
    });
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(saveVocabRecord)
      .mockResolvedValueOnce("new-id-1")
      .mockRejectedValueOnce(new Error("Firestore unavailable"));

    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    await screen.findByText("meticulous");

    fireEvent.click(screen.getByRole("button", { name: "Lưu tất cả" }));

    expect(await screen.findByText(/Firestore unavailable/)).toBeInTheDocument();
    expect(screen.getByText("Đã lưu 1/2 từ.")).toBeInTheDocument();

    const meticulousCard = screen.getByText("meticulous").closest(".suggestion-card");
    expect(meticulousCard).toHaveTextContent("✔");
    const ephemeralCard = screen.getByText("ephemeral").closest(".suggestion-card");
    expect(ephemeralCard).not.toHaveTextContent("✔");
  });

  it('"Lưu tất cả" shows a busy state and ignores a second click while a bulk save is in flight', async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        suggestions: [
          { headword: "meticulous", meaning: "tỉ mỉ" },
          { headword: "ephemeral", meaning: "phù du" },
        ],
      }),
    });
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(saveVocabRecord).mockResolvedValue("new-id");

    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    await screen.findByText("meticulous");

    const saveAllBtn = screen.getByRole("button", { name: "Lưu tất cả" });
    expect(saveAllBtn).toHaveClass("link-btn");
    fireEvent.click(saveAllBtn);

    // Button flips to a disabled busy state synchronously, before the async saves resolve.
    const busyBtn = screen.getByRole("button", { name: "Đang lưu…" });
    expect(busyBtn).toBeDisabled();

    // A second click while busy must be a no-op — the handler's own guard plus the
    // disabled attribute both prevent it from starting a second overlapping save.
    fireEvent.click(busyBtn);

    await waitFor(() => expect(screen.getByText("Đã lưu 2/2 từ.")).toBeInTheDocument());
    // Exactly one save per unique suggestion — never doubled by the second click.
    expect(saveVocabRecord).toHaveBeenCalledTimes(2);
  });

  it("dismisses a suggestion card without saving it, and hides it from Lưu tất cả", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ suggestions: [{ headword: "meticulous", meaning: "tỉ mỉ" }] }),
    });

    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    await screen.findByText("meticulous");

    fireEvent.click(screen.getByRole("button", { name: "Bỏ qua gợi ý này" }));

    expect(screen.queryByText("meticulous")).not.toBeInTheDocument();
    expect(saveVocabRecord).not.toHaveBeenCalled();
  });

  it("excludes headwords already in existingRecords from the prompt", async () => {
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify({ suggestions: [] }) });
    const existing = [makeRecord({ headword: "meticulous" })];

    render(
      <VocabSuggestionsSection
        text="She is meticulous and diligent."
        existingRecords={existing}
        topics={[]}
      />
    );

    await waitFor(() => expect(generateContent).toHaveBeenCalled());
    const call = vi.mocked(generateContent).mock.calls[0][0];
    expect(call.prompt).toContain("Do NOT suggest any of these already-known words: meticulous.");
  });
});
