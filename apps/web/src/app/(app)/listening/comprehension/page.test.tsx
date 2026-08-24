import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import ComprehensionPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { synthesizeSpeech } from "@/lib/synthesizeSpeechClient";
import { getRandomSavedListeningExercise, saveListeningExercise } from "@/lib/savedListeningExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
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

const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini",
  providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" } },
};

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

const VALID_PASSAGE_JSON = {
  kind: "conversation",
  turns: [
    { speaker: "A", gender: "male", text: "Welcome to the store." },
    { speaker: "B", gender: "female", text: "Thanks, I need a laptop." },
  ],
  questions: [
    { question: "What does B need?", options: ["A laptop", "A phone", "A book", "A chair"], correctIndex: 0 },
    { question: "Where are they?", options: ["A store", "A park", "A school", "A gym"], correctIndex: 0 },
    { question: "Who speaks first?", options: ["A", "B", "Neither", "Both"], correctIndex: 0 },
  ],
};

beforeEach(() => {
  vi.clearAllMocks();
  setSearchParams({ context: "general", level: "b1", action: "generate" });
  vi.mocked(getVocabRecords).mockResolvedValue([]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
  vi.mocked(getRandomSavedListeningExercise).mockResolvedValue(null);
  vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(VALID_PASSAGE_JSON) });

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

describe("ComprehensionPage (language gate)", () => {
  it("blocks the session when targetLanguage is not english, never calling generateContent", async () => {
    mockSignedIn({ ...SETTINGS_WITH_KEY, targetLanguage: "japanese" });
    render(<ComprehensionPage />);
    expect(
      await screen.findByText("Nghe hiểu hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });
});

describe("ComprehensionPage (generate + session)", () => {
  it("auto-generates a passage on mount and is never gated on vocab count", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    expect(await screen.findByText("Lượt 1/2 — Người nói A")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalledTimes(1);
  });

  it("shows all 3 questions together and gates Nộp bài on all being answered, with no listen requirement", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();

    const options = screen.getAllByRole("button", { name: "A laptop" });
    fireEvent.click(options[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A store" })[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A" })[0]);

    // No play() was ever called, and Nộp bài is still enabled — no listen-gate.
    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();
  });

  it("prefetches both turns' audio on generate, tagged with distinct voices for a male/female pair", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");

    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Welcome to the store.", language: "en", voice: "male1" });
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Thanks, I need a laptop.", language: "en", voice: "female1" });
  });

  it("fetchSavedExercise (action=existing) passes level: null to the saved-exercise lookup when the URL has no level param, rather than coercing to b1", async () => {
    mockSignedIn();
    setSearchParams({ context: "general", action: "existing" });
    vi.mocked(getRandomSavedListeningExercise).mockResolvedValue({
      id: "saved-1",
      type: "comprehension",
      item: {
        kind: "conversation",
        turns: [
          { speaker: "A", text: "Welcome to the store." },
          { speaker: "B", text: "Thanks, I need a laptop." },
        ],
        questions: VALID_PASSAGE_JSON.questions,
        speakerGenders: { A: "male", B: "female" },
      },
      generationFilters: { context: "general", level: "c1" },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });

    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");

    expect(getRandomSavedListeningExercise).toHaveBeenCalledWith(
      "u1",
      "english",
      "comprehension",
      { context: "general", level: null },
      undefined
    );
  });
});

describe("ComprehensionPage (seek slider drag guard)", () => {
  it("does not seek while dragging (multiple onChange ticks), only once on release", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));
    vi.mocked(synthesizeSpeech).mockClear();

    const slider = screen.getByLabelText("Tua theo từ");
    fireEvent.mouseDown(slider);
    fireEvent.change(slider, { target: { value: "2" } });
    fireEvent.change(slider, { target: { value: "3" } });
    fireEvent.change(slider, { target: { value: "4" } });
    expect(synthesizeSpeech).not.toHaveBeenCalled();

    fireEvent.mouseUp(slider, { target: { value: "4" } });
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(1));
  });

  it("disables the slider while a seek is in flight, re-enabling once it resolves", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    let resolveSeek!: (v: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          resolveSeek = resolve;
        })
    );

    const slider = screen.getByLabelText("Tua theo từ");
    fireEvent.mouseDown(slider);
    fireEvent.change(slider, { target: { value: "3" } });
    fireEvent.mouseUp(slider, { target: { value: "3" } });

    await waitFor(() => expect(slider).toBeDisabled());
    resolveSeek({ audioBase64: "SEEK" });
    await waitFor(() => expect(slider).not.toBeDisabled());
  });
});

describe("ComprehensionPage (submit stops playback)", () => {
  it("handleSubmit pauses any in-progress audio before showing the result phase", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "⏹ Dừng" })).toBeInTheDocument());
    const pauseSpy = vi.spyOn(audioInstances[audioInstances.length - 1], "pause");

    fireEvent.click(screen.getAllByRole("button", { name: "A laptop" })[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A store" })[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A" })[0]);
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));

    await screen.findByText("3/3");
    expect(pauseSpy).toHaveBeenCalled();
  });
});

describe("ComprehensionPage (result + save/reuse)", () => {
  async function completeSession() {
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");
    fireEvent.click(screen.getAllByRole("button", { name: "A laptop" })[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A store" })[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A" })[0]);
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("3/3");
  }

  it("shows correctCount/3 and a full transcript with speaker labels", async () => {
    mockSignedIn();
    await completeSession();
    expect(screen.getByText("A: Welcome to the store.")).toBeInTheDocument();
    expect(screen.getByText("B: Thanks, I need a laptop.")).toBeInTheDocument();
  });

  it("offers Lưu bài for a generated session", async () => {
    mockSignedIn();
    vi.mocked(saveListeningExercise).mockResolvedValue("new-id");
    await completeSession();
    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));
    await waitFor(() =>
      expect(saveListeningExercise).toHaveBeenCalledWith(
        "u1",
        "comprehension",
        expect.objectContaining({ kind: "conversation" }),
        { context: "general", level: "b1" },
        "english"
      )
    );
  });

  it("hides Lưu bài for a reused (already-saved) session", async () => {
    mockSignedIn();
    setSearchParams({ context: "general", level: "b1", action: "existing" });
    vi.mocked(getRandomSavedListeningExercise).mockResolvedValue({
      id: "saved-1",
      type: "comprehension",
      item: {
        kind: "conversation",
        turns: [
          { speaker: "A", text: "Welcome to the store." },
          { speaker: "B", text: "Thanks, I need a laptop." },
        ],
        questions: VALID_PASSAGE_JSON.questions,
        speakerGenders: { A: "male", B: "female" },
      },
      generationFilters: { context: "general", level: "b1" },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });
    await completeSession();
    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });

  it("a reused session's persisted speakerGenders genuinely drive voice assignment, not a same-gender collapse", async () => {
    mockSignedIn();
    setSearchParams({ context: "general", level: "b1", action: "existing" });
    vi.mocked(getRandomSavedListeningExercise).mockResolvedValue({
      id: "saved-1",
      type: "comprehension",
      item: {
        kind: "conversation",
        turns: [
          { speaker: "A", text: "Welcome to the store." },
          { speaker: "B", text: "Thanks, I need a laptop." },
        ],
        questions: VALID_PASSAGE_JSON.questions,
        speakerGenders: { A: "male", B: "female" },
      },
      generationFilters: { context: "general", level: "b1" },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });

    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    // Proves speakerGenders (A: male, B: female) actually drove voice
    // assignment — without it, assignVoices' "default to female" fallback
    // would collapse both A and B onto female1/female2.
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Welcome to the store.", language: "en", voice: "male1" });
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Thanks, I need a laptop.", language: "en", voice: "female1" });
  });

  it("'Bài khác' generates a fresh passage for a generated session and returns to the session phase", async () => {
    mockSignedIn();
    await completeSession();
    // The result phase's VocabSuggestionsSection also calls generateContent
    // (for AI vocab suggestions), so the baseline isn't necessarily 1 — what
    // matters is that "Bài khác" triggers exactly one MORE call (a fresh
    // handleGenerate), not that the running total is any particular number.
    const callsBeforeBaiKhac = vi.mocked(generateContent).mock.calls.length;

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    await waitFor(() => expect(generateContent).toHaveBeenCalledTimes(callsBeforeBaiKhac + 1));
    expect(await screen.findByText("Lượt 1/2 — Người nói A")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeInTheDocument();
  });
});
