import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import PracticePage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords, updateVocabRecordSm2, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { computeSm2 } from "@/lib/sm2";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn(), updateVocabRecordSm2: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/sm2", () => ({ computeSm2: vi.fn() }));

beforeEach(() => {
  vi.clearAllMocks();
  // Every session-phase test can reach the "result" phase by grading the last word, which
  // fires the batch SM-2 write effect — give it harmless defaults so tests that don't care
  // about SM-2 output (e.g. the session-phase progression tests) don't crash on an
  // unconfigured mock. Result-phase tests override these with their own assertions-relevant
  // return values.
  vi.mocked(computeSm2).mockReturnValue({
    sm2Repetitions: 1,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    nextReviewAt: "2026-08-18T00:00:00.000Z",
    updatedAt: "2026-08-17T00:00:00.000Z",
  });
  vi.mocked(updateVocabRecordSm2).mockResolvedValue(undefined);
});
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

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

describe("PracticePage (setup phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<PracticePage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the matching word count and enables Bắt đầu once records load", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    expect(await screen.findByText("2 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Bắt đầu" })).not.toBeDisabled();
  });

  it("disables Bắt đầu when no word matches the filters", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    expect(await screen.findByText("0 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Bắt đầu" })).toBeDisabled();
  });

  it("filters the preview count by the selected maximum CEFR level", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", cefrLevel: "a1" }),
      makeRecord({ id: "2", cefrLevel: "c1" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    await screen.findByText("2 từ khớp bộ lọc hiện tại.");

    fireEvent.change(screen.getByDisplayValue("Mọi trình độ"), { target: { value: "a1" } });

    expect(await screen.findByText("1 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
  });

  it("highlights the CEFR and word-count selects when set away from their defaults", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    const cefrSelect = await screen.findByDisplayValue("Mọi trình độ");
    const countSelect = screen.getByDisplayValue("10 từ");
    expect(cefrSelect).not.toHaveClass("active");
    expect(countSelect).not.toHaveClass("active");

    fireEvent.change(cefrSelect, { target: { value: "a1" } });
    fireEvent.change(countSelect, { target: { value: "5" } });

    expect(cefrSelect).toHaveClass("active");
    expect(countSelect).toHaveClass("active");
  });

  it("leaves the setup screen when Bắt đầu is clicked with matching words", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));

    await waitFor(() =>
      expect(screen.queryByRole("button", { name: "Bắt đầu" })).not.toBeInTheDocument()
    );
  });
});

describe("PracticePage (session phase)", () => {
  it("shows the current word's flashcard and a progress indicator, advancing on each grade", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", headword: "first" }),
      makeRecord({ id: "2", headword: "second" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);

    // selectSessionWords shuffles its pool via Math.random (Fisher-Yates) before returning it
    // (see src/lib/practiceSession.ts). Pin it so the session's word order is deterministic —
    // random() >= 0.5 makes every swap a no-op, preserving the input order.
    const randomSpy = vi.spyOn(Math, "random").mockReturnValue(0.99);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));

    expect(await screen.findByText("Từ 1 / 2")).toBeInTheDocument();
    expect(screen.getByText("first")).toBeInTheDocument();

    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));

    expect(await screen.findByText("Từ 2 / 2")).toBeInTheDocument();
    expect(screen.getByText("second")).toBeInTheDocument();

    randomSpy.mockRestore();
  });

  it("transitions past the session UI once the last word is graded", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", headword: "only" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));
    await screen.findByText("only");

    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Chưa hiểu" }));

    await waitFor(() => expect(screen.queryByTestId("flashcard-card")).not.toBeInTheDocument());
  });
});

describe("PracticePage (result phase)", () => {
  it("shows the percentage and per-word results, and writes one batch SM-2 update per word", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", headword: "first", meaning: "nghĩa 1" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(computeSm2).mockReturnValue({
      sm2Repetitions: 1,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      nextReviewAt: "2026-08-18T00:00:00.000Z",
      updatedAt: "2026-08-17T00:00:00.000Z",
    });
    vi.mocked(updateVocabRecordSm2).mockResolvedValue(undefined);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));
    await screen.findByText("first");

    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));

    expect(await screen.findByText("100%")).toBeInTheDocument();
    expect(screen.getByText("Đúng 1 / 1 từ")).toBeInTheDocument();
    expect(screen.getByText("nghĩa 1")).toBeInTheDocument();

    await waitFor(() =>
      expect(updateVocabRecordSm2).toHaveBeenCalledWith(
        "u1",
        "1",
        expect.objectContaining({ sm2Repetitions: 1 })
      )
    );
    expect(computeSm2).toHaveBeenCalledTimes(1);
  });

  it('returns to the setup phase when "Về Ôn tập" is clicked', async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", headword: "first" })]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(computeSm2).mockReturnValue({
      sm2Repetitions: 1,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      nextReviewAt: "2026-08-18T00:00:00.000Z",
      updatedAt: "2026-08-17T00:00:00.000Z",
    });
    vi.mocked(updateVocabRecordSm2).mockResolvedValue(undefined);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));
    await screen.findByText("first");
    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));

    fireEvent.click(await screen.findByRole("button", { name: "Về Ôn tập" }));
    expect(await screen.findByRole("button", { name: "Bắt đầu" })).toBeInTheDocument();
  });

  it('"Ôn tập lại ngay" starts a new session immediately, without returning to setup', async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", headword: "first" })]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(computeSm2).mockReturnValue({
      sm2Repetitions: 1,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      nextReviewAt: "2026-08-18T00:00:00.000Z",
      updatedAt: "2026-08-17T00:00:00.000Z",
    });
    vi.mocked(updateVocabRecordSm2).mockResolvedValue(undefined);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));
    await screen.findByText("first");
    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));
    await screen.findByText("100%");

    fireEvent.click(screen.getByRole("button", { name: "Ôn tập lại ngay" }));

    // Straight back into the session phase (progress indicator + flashcard),
    // not the setup phase's filters/"Bắt đầu" button.
    expect(await screen.findByText("Từ 1 / 1")).toBeInTheDocument();
    expect(screen.getByTestId("flashcard-card")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Bắt đầu" })).not.toBeInTheDocument();
  });
});
