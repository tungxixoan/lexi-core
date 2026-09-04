import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import ReadingHubPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { VOLUME_LABELS } from "@/lib/toeicFilters";
import { DEFAULT_SETTINGS } from "@/lib/settings";

const VOLUME_LABEL_VOL2 = VOLUME_LABELS.vol2;

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

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

function mockSignedIn() {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(useSettingsContext).mockReturnValue({
    settings: DEFAULT_SETTINGS,
    loading: false,
    error: null,
    save: vi.fn(),
  } as never);
});

describe("ReadingHubPage (auth)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<ReadingHubPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });
});

describe("ReadingHubPage (mode picker)", () => {
  it("hides the secondary filter and action buttons until a mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    await screen.findByRole("button", { name: /Đọc & gõ/ });

    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeInTheDocument();
  });

  it("shows Đọc & gõ's own secondary filters (Trình độ, Số từ) once that mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}` }))
    );

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: "Mọi trình độ ▾" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "10 từ ▾" })).toBeInTheDocument();
  });

  it("shows Part 5's own secondary filter (Độ khó chips) once that mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 5/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 })).toBeInTheDocument();
  });

  it("shows the min-words hint instead of the generate button for Đọc & gõ when fewer than 5 words match", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));

    expect(
      await screen.findByText("Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có 2 từ.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
  });

  it("Part 5's 'Lấy bài có sẵn' is never gated by word count, even with 0 matching words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 5/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });

  it("shows Part 6's own secondary filter (Độ khó chips) once that mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 6/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 })).toBeInTheDocument();
  });

  it("Part 6's 'Lấy bài có sẵn' is never gated by word count, even with 0 matching words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 6/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });

  it("shows Part 7's own secondary filter (Độ khó chips) once that mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 7/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 })).toBeInTheDocument();
  });

  it("Part 7's 'Lấy bài có sẵn' is never gated by word count, even with 0 matching words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 7/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });
});

describe("ReadingHubPage (navigation)", () => {
  it("navigates to /reading/bilingual with the selected filters and action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}` }))
    );

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/bilingual?wordCount=10&action=generate");
  });

  it("navigates to /reading/bilingual with action=existing for 'Lấy bài có sẵn'", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));
    fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/bilingual?wordCount=10&action=existing");
  });

  it("includes selected topicIds and maxCefr in the query string when set", async () => {
    mockSignedIn();
    const topics: Topic[] = [{ id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" }];
    vi.mocked(getTopics).mockResolvedValue(topics);
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, topicIds: ["biz-1"] }))
    );

    render(<ReadingHubPage />);
    fireEvent.click(screen.getByRole("button", { name: /Chủ đề/ }));
    fireEvent.click(await screen.findByRole("button", { name: "💼 Business" }));
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));
    fireEvent.click(screen.getByRole("button", { name: "Mọi trình độ ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "Tối đa B1" }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    const url = pushMock.mock.calls[0][0] as string;
    expect(url).toContain("topicIds=biz-1");
    expect(url).toContain("maxCefr=b1");
  });

  it("navigates to /reading/part5 with selected volumes and action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 5/ }));
    fireEvent.click(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/part5?volumes=vol2&action=generate");
  });

  it("navigates to /reading/part6 with selected volumes and action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 6/ }));
    fireEvent.click(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/part6?volumes=vol2&action=generate");
  });

  it("navigates to /reading/part7 with selected volumes and action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 7/ }));
    fireEvent.click(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/part7?volumes=vol2&action=generate");
  });
});
