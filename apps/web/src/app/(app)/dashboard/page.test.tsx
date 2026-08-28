import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import DashboardPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getDailyActivity } from "@/lib/dailyActivity";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
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
  vi.mocked(useSettingsContext).mockReturnValue({
    settings: DEFAULT_SETTINGS,
    loading: false,
    error: null,
    save: vi.fn(),
  } as never);
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

describe("DashboardPage (7-day chart)", () => {
  // Mirrors page.tsx's own dateKey/lastNDays helpers so the expected day keys
  // always line up with "today" regardless of when this test actually runs —
  // avoids needing to fake system time (and the testing-library/fake-timer
  // interaction flakiness that comes with it).
  function dateKey(d: Date): string {
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const dd = String(d.getDate()).padStart(2, "0");
    return `${yyyy}-${mm}-${dd}`;
  }

  function lastNDays(n: number, from: Date = new Date()): string[] {
    const keys: string[] = [];
    for (let i = n - 1; i >= 0; i--) {
      keys.push(dateKey(new Date(from.getTime() - i * 24 * 60 * 60 * 1000)));
    }
    return keys;
  }

  it("renders 7 day-columns in chronological order, zero-filling days with no weeklyLog entry, with today's column marked", async () => {
    const days = lastNDays(7);
    // Only 3 of the 7 days have a weeklyLog entry (including today, the last
    // day) — the other 4 must still render their own column with value 0
    // rather than being skipped or crashing.
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getDailyActivity).mockResolvedValue({
      currentStreak: 1,
      lastPracticedDate: days[6],
      weeklyLog: {
        [days[0]]: 3,
        [days[2]]: 5,
        [days[6]]: 2,
      },
    });

    const { container } = render(<DashboardPage />);
    await screen.findByText("7 ngày gần đây");

    const columns = container.querySelectorAll(".dash-chart-col");
    expect(columns).toHaveLength(7);

    const values = Array.from(columns).map((col) => col.querySelector(".dash-chart-value")?.textContent);
    expect(values).toEqual(["3", "0", "5", "0", "0", "0", "2"]);

    // Today (the last, chronologically most recent column) is visually
    // distinguished via the "today" class; no other column carries it.
    columns.forEach((col, i) => {
      if (i === 6) {
        expect(col).toHaveClass("today");
      } else {
        expect(col).not.toHaveClass("today");
      }
    });
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

  it("shows an inline error for the stats section without breaking the streak banner when getVocabRecords fails", async () => {
    vi.mocked(getVocabRecords).mockRejectedValue(new Error("network down"));
    vi.mocked(getDailyActivity).mockResolvedValue({ currentStreak: 5, lastPracticedDate: "2026-08-25", weeklyLog: {} });
    render(<DashboardPage />);
    expect(await screen.findByRole("alert")).toBeInTheDocument();
    expect(screen.getByText("5")).toBeInTheDocument(); // streak banner still renders
    expect(screen.queryByText("Hôm nay")).not.toBeInTheDocument(); // stat cards do not render
    expect(screen.queryByText("Theo cấp độ CEFR")).not.toBeInTheDocument(); // CEFR breakdown does not render
  });
});
