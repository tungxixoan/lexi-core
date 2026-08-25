import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import DashboardPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getDailyActivity } from "@/lib/dailyActivity";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/dailyActivity", () => ({ getDailyActivity: vi.fn() }));
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
});

describe("DashboardPage (auth)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<DashboardPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });
});

describe("DashboardPage (streak + stats)", () => {
  it("shows the fire banner with the current streak when > 0", async () => {
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);
    vi.mocked(getDailyActivity).mockResolvedValue({ currentStreak: 12, lastPracticedDate: "2026-08-25", weeklyLog: {} });
    render(<DashboardPage />);
    expect(await screen.findByText("12")).toBeInTheDocument();
    expect(screen.getByText(/🔥/)).toBeInTheDocument();
  });

  it("shows the neutral/cold state when streak is 0", async () => {
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getDailyActivity).mockResolvedValue({ currentStreak: 0, lastPracticedDate: null, weeklyLog: {} });
    render(<DashboardPage />);
    expect(await screen.findByText(/Chưa có streak/)).toBeInTheDocument();
  });

  it("shows dueCount and masteredCount computed from the fetched records", async () => {
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", nextReviewAt: null }), // due
      makeRecord({ id: "2", sm2Interval: 21 }), // mastered
      makeRecord({ id: "3", sm2Interval: 21 }), // mastered
    ]);
    vi.mocked(getDailyActivity).mockResolvedValue({ currentStreak: 1, lastPracticedDate: "2026-08-25", weeklyLog: {} });
    render(<DashboardPage />);
    expect(await screen.findByText("1")).toBeInTheDocument(); // due count
    expect(screen.getByText("2")).toBeInTheDocument(); // mastered count
  });

  it("the CTA button reflects dueCount and is absent when dueCount is 0", async () => {
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", nextReviewAt: "2099-01-01T00:00:00.000Z" })]); // not due
    vi.mocked(getDailyActivity).mockResolvedValue({ currentStreak: 0, lastPracticedDate: null, weeklyLog: {} });
    render(<DashboardPage />);
    await screen.findByText(/Chưa có streak/);
    expect(screen.queryByRole("link", { name: /Ôn .* từ ngay/ })).not.toBeInTheDocument();
  });

  it("the CTA link points to /practice?action=start", async () => {
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", nextReviewAt: null })]);
    vi.mocked(getDailyActivity).mockResolvedValue({ currentStreak: 3, lastPracticedDate: "2026-08-25", weeklyLog: {} });
    render(<DashboardPage />);
    const link = await screen.findByRole("link", { name: "Ôn 1 từ ngay" });
    expect(link).toHaveAttribute("href", "/practice?action=start");
  });
});

describe("DashboardPage (error handling)", () => {
  it("shows an inline error for the streak/activity section without breaking the stat cards", async () => {
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", nextReviewAt: null })]);
    vi.mocked(getDailyActivity).mockRejectedValue(new Error("network down"));
    render(<DashboardPage />);
    expect(await screen.findByRole("alert")).toBeInTheDocument();
    expect(screen.getByText("Hôm nay")).toBeInTheDocument(); // stat cards still render
  });
});
