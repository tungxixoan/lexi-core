# Tổng quan (Dashboard) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the "Tổng quan" (Dashboard) page on the web app — streak, due-today count, mastered count, CEFR breakdown, and a 7-day activity chart, plus a whole-app daily-activity streak that counts sessions completed across every existing exercise type (matching Flutter's Plan 5 feature exactly), replacing the sidebar's already-linked but 404ing `/dashboard`.

**Architecture:** Two new client-side library modules — `learningStats.ts` (pure computation over already-fetched `VocabRecord[]`, no new persistence) and `dailyActivity.ts` (a new single Firestore doc per user, `users/{uid}/stats/activity`, mirroring `settings.ts`'s existing single-doc pattern since the web app has no local-storage layer to port Flutter's SharedPreferences-based streak from). A new `/dashboard` page consumes both. 7 existing result pages each get one new best-effort `recordDailyActivity` call where their result phase is reached. `/practice` gains a `?action=start` query param that auto-starts a due-words session.

**Tech Stack:** Next.js/React, Firestore, Vitest + Testing Library.

## Global Constraints

- Vietnamese-first UI: every new user-facing string is Vietnamese.
- Streak/weekly-log scope matches Flutter exactly: counts activity from **all 7** result screens (Đọc & gõ, Part 5/6/7, Nghe chép, Nghe hiểu, Ôn tập) — not narrowed to Ôn tập alone.
- `masteredCount` = `sm2Interval >= 21` — exact threshold, ported from `stats_service.dart`, not approximated.
- `recordDailyActivity` calls are **best-effort everywhere** — a failure must never block or delay the result screen it's called from (console.error only, matching this app's existing `updateVocabRecordSm2` failure-handling precedent on every result page).
- No new charting dependency — the 7-day chart is hand-rolled with CSS (divs sized by percentage height), matching Flutter's own hand-rolled `CustomPainter` approach.
- `computeLearningStats`/`recordDailyActivity`'s streak logic must match `stats_service.dart`'s real behavior exactly (same-day repeat = no streak change but log still accumulates; consecutive day = +1; any other gap, including never-practiced = resets to 1; weekly log prunes entries older than 6 days ago).

---

## Task 1: `apps/web/src/lib/learningStats.ts` — pure stats computation

**Files:**
- Create: `apps/web/src/lib/learningStats.ts`
- Create: `apps/web/src/lib/learningStats.test.ts`

**Interfaces:**
- Consumes: `VocabRecord` type from `./vocabRecords` (existing — has `nextReviewAt: string | null`, `sm2Interval: number`, `cefrLevel: "a1"|"a2"|"b1"|"b2"|"c1"|"c2"`).
- Produces: `LearningStats` interface, `MASTERED_INTERVAL_THRESHOLD` constant, `computeLearningStats(records, now?): LearningStats`. Task 3 (`/dashboard` page) is the consumer.

### Context

Read `lib/core/services/stats_service.dart` and `test/core/services/stats_service_test.dart` in full first — this task ports `computeStats()`'s due/mastered/CEFR logic exactly (not the streak/weeklyLog half, which reads from SharedPreferences — that's Task 2's job, backed by Firestore instead).

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/learningStats.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { computeLearningStats, MASTERED_INTERVAL_THRESHOLD } from "./learningStats";
import type { VocabRecord } from "./vocabRecords";

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

describe("computeLearningStats", () => {
  it("returns all zeros for an empty record list", () => {
    const stats = computeLearningStats([]);
    expect(stats.dueCount).toBe(0);
    expect(stats.masteredCount).toBe(0);
    expect(stats.totalCount).toBe(0);
    expect(stats.cefrBreakdown).toEqual({ a1: 0, a2: 0, b1: 0, b2: 0, c1: 0, c2: 0 });
  });

  it("counts due-by-null and due-by-past-date, excludes future nextReviewAt", () => {
    const now = new Date("2026-08-25T12:00:00.000Z");
    const records = [
      makeRecord({ id: "1", nextReviewAt: null }), // due
      makeRecord({ id: "2", nextReviewAt: "2026-08-25T11:00:00.000Z" }), // due (past)
      makeRecord({ id: "3", nextReviewAt: "2026-09-01T00:00:00.000Z" }), // not due (future)
    ];
    const stats = computeLearningStats(records, now);
    expect(stats.dueCount).toBe(2);
  });

  it("mastered threshold is exactly sm2Interval >= 21", () => {
    const records = [
      makeRecord({ id: "1", sm2Interval: 20 }),
      makeRecord({ id: "2", sm2Interval: 21 }),
      makeRecord({ id: "3", sm2Interval: 100 }),
    ];
    const stats = computeLearningStats(records);
    expect(stats.masteredCount).toBe(2);
    expect(MASTERED_INTERVAL_THRESHOLD).toBe(21);
  });

  it("builds a CEFR breakdown across all 6 levels, including zero-count levels", () => {
    const records = [
      makeRecord({ id: "1", cefrLevel: "a1" }),
      makeRecord({ id: "2", cefrLevel: "a1" }),
      makeRecord({ id: "3", cefrLevel: "b2" }),
    ];
    const stats = computeLearningStats(records);
    expect(stats.cefrBreakdown.a1).toBe(2);
    expect(stats.cefrBreakdown.b2).toBe(1);
    expect(stats.cefrBreakdown.c1).toBe(0);
    expect(stats.totalCount).toBe(3);
  });
});
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run src/lib/learningStats.test.ts`
Expected: FAIL — the module doesn't exist yet.

- [ ] **Step 3: Implement `learningStats.ts`**

Create `apps/web/src/lib/learningStats.ts`:

```ts
import type { VocabRecord } from "./vocabRecords";

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];

export interface LearningStats {
  dueCount: number;
  masteredCount: number;
  totalCount: number;
  cefrBreakdown: Record<CefrLevel, number>;
}

// Ports StatsService.computeStats()'s mastered threshold exactly.
export const MASTERED_INTERVAL_THRESHOLD = 21;

function isDue(record: VocabRecord, now: Date): boolean {
  return record.nextReviewAt === null || new Date(record.nextReviewAt).getTime() <= now.getTime();
}

// Ports StatsService.computeStats()'s due/mastered/CEFR logic exactly —
// the streak/weeklyLog half lives in dailyActivity.ts instead, since that
// part is persisted (Firestore) rather than derived fresh every call.
export function computeLearningStats(records: VocabRecord[], now: Date = new Date()): LearningStats {
  let dueCount = 0;
  let masteredCount = 0;
  const cefrBreakdown = Object.fromEntries(CEFR_LEVELS.map((l) => [l, 0])) as Record<CefrLevel, number>;

  for (const r of records) {
    if (isDue(r, now)) dueCount++;
    if (r.sm2Interval >= MASTERED_INTERVAL_THRESHOLD) masteredCount++;
    cefrBreakdown[r.cefrLevel] = (cefrBreakdown[r.cefrLevel] ?? 0) + 1;
  }

  return { dueCount, masteredCount, totalCount: records.length, cefrBreakdown };
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run src/lib/learningStats.test.ts`
Expected: all tests PASS.

- [ ] **Step 5: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/learningStats.ts apps/web/src/lib/learningStats.test.ts
git commit -m "feat(web): add learningStats — due/mastered/CEFR computation for the dashboard"
```

---

## Task 2: `apps/web/src/lib/dailyActivity.ts` — streak/weekly-log persistence

**Files:**
- Create: `apps/web/src/lib/dailyActivity.ts`
- Create: `apps/web/src/lib/dailyActivity.test.ts`

**Interfaces:**
- Consumes: `getFirebaseDb` from `./firebase` (existing, same as `settings.ts`).
- Produces: `DailyActivity` interface, `getDailyActivity(uid): Promise<DailyActivity>`, `recordDailyActivity(uid, wordCount, now?): Promise<void>`. Task 3 (`/dashboard` page) calls `getDailyActivity`. Task 4 and Task 5 (the 7 result-page integrations) call `recordDailyActivity`.

### Context

Read `apps/web/src/lib/settings.ts` in full first — this task mirrors its exact single-doc-per-user pattern (`getSettings`/`saveSettings` → `getDailyActivity`/`recordDailyActivity`), just at a different Firestore path and with read-modify-write logic instead of a flat overwrite. Also re-read `lib/core/services/stats_service.dart`'s `recordPracticeSession` and `test/core/services/stats_service_test.dart`'s streak test — this task ports that logic exactly.

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/dailyActivity.test.ts`. Mock `firebase/firestore` the same way `apps/web/src/lib/settings.test.ts` does (read that file first for the exact mock shape/conventions to mirror):

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";
import { getDailyActivity, recordDailyActivity } from "./dailyActivity";

const mockDocData = new Map<string, Record<string, unknown>>();

vi.mock("firebase/firestore", () => ({
  doc: (_db: unknown, ...segments: string[]) => ({ path: segments.join("/") }),
  getDoc: async (ref: { path: string }) => ({
    exists: () => mockDocData.has(ref.path),
    data: () => mockDocData.get(ref.path),
  }),
  setDoc: async (ref: { path: string }, data: Record<string, unknown>) => {
    mockDocData.set(ref.path, data);
  },
}));

vi.mock("./firebase", () => ({ getFirebaseDb: () => ({}) }));

const UID = "user-123";

beforeEach(() => {
  mockDocData.clear();
});

describe("getDailyActivity", () => {
  it("returns zero-value defaults when no doc exists yet", async () => {
    const activity = await getDailyActivity(UID);
    expect(activity).toEqual({ currentStreak: 0, lastPracticedDate: null, weeklyLog: {} });
  });
});

describe("recordDailyActivity", () => {
  it("starts a new streak at 1 on the very first call", async () => {
    await recordDailyActivity(UID, 5, new Date("2026-08-25T10:00:00.000Z"));
    const activity = await getDailyActivity(UID);
    expect(activity.currentStreak).toBe(1);
    expect(activity.lastPracticedDate).toBe("2026-08-25");
    expect(activity.weeklyLog["2026-08-25"]).toBe(5);
  });

  it("does not change the streak on a same-day repeat call, but accumulates the log", async () => {
    await recordDailyActivity(UID, 5, new Date("2026-08-25T10:00:00.000Z"));
    await recordDailyActivity(UID, 3, new Date("2026-08-25T18:00:00.000Z"));
    const activity = await getDailyActivity(UID);
    expect(activity.currentStreak).toBe(1);
    expect(activity.weeklyLog["2026-08-25"]).toBe(8);
  });

  it("increments the streak when the last practiced day was yesterday", async () => {
    await recordDailyActivity(UID, 5, new Date("2026-08-24T10:00:00.000Z"));
    await recordDailyActivity(UID, 3, new Date("2026-08-25T10:00:00.000Z"));
    const activity = await getDailyActivity(UID);
    expect(activity.currentStreak).toBe(2);
  });

  it("resets the streak to 1 on any gap larger than one day", async () => {
    await recordDailyActivity(UID, 5, new Date("2026-08-20T10:00:00.000Z"));
    await recordDailyActivity(UID, 3, new Date("2026-08-25T10:00:00.000Z"));
    const activity = await getDailyActivity(UID);
    expect(activity.currentStreak).toBe(1);
  });

  it("prunes weeklyLog entries older than 6 days ago, keeps exactly-6-days-old ones", async () => {
    await recordDailyActivity(UID, 1, new Date("2026-08-18T10:00:00.000Z")); // exactly 7 days before the 25th — should be pruned
    await recordDailyActivity(UID, 2, new Date("2026-08-19T10:00:00.000Z")); // exactly 6 days before — kept
    await recordDailyActivity(UID, 3, new Date("2026-08-25T10:00:00.000Z"));
    const activity = await getDailyActivity(UID);
    expect(activity.weeklyLog["2026-08-18"]).toBeUndefined();
    expect(activity.weeklyLog["2026-08-19"]).toBe(2);
    expect(activity.weeklyLog["2026-08-25"]).toBe(3);
  });
});
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run src/lib/dailyActivity.test.ts`
Expected: FAIL — the module doesn't exist yet.

- [ ] **Step 3: Implement `dailyActivity.ts`**

Create `apps/web/src/lib/dailyActivity.ts`:

```ts
import { doc, getDoc, setDoc } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";

export interface DailyActivity {
  currentStreak: number;
  lastPracticedDate: string | null; // "yyyy-MM-dd"
  weeklyLog: Record<string, number>; // "yyyy-MM-dd" -> word count that day
}

const DEFAULT_ACTIVITY: DailyActivity = { currentStreak: 0, lastPracticedDate: null, weeklyLog: {} };

function activityRef(uid: string) {
  return doc(getFirebaseDb(), "users", uid, "stats", "activity");
}

function dateKey(d: Date): string {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

export async function getDailyActivity(uid: string): Promise<DailyActivity> {
  const snap = await getDoc(activityRef(uid));
  if (!snap.exists()) return DEFAULT_ACTIVITY;
  const stored = snap.data() as Partial<DailyActivity>;
  return { ...DEFAULT_ACTIVITY, ...stored };
}

// Ports StatsService.recordPracticeSession(wordCount) exactly: same-day
// repeat call leaves the streak unchanged but still accumulates that
// day's log entry; yesterday -> +1; any other gap (including never
// having practiced) -> resets to 1. Prunes weeklyLog entries dated more
// than 6 days before `now` (keeps a rolling 7-day window: today + 6
// prior days).
export async function recordDailyActivity(uid: string, wordCount: number, now: Date = new Date()): Promise<void> {
  const current = await getDailyActivity(uid);
  const today = dateKey(now);
  const yesterday = dateKey(new Date(now.getTime() - 24 * 60 * 60 * 1000));

  let newStreak: number;
  if (current.lastPracticedDate === today) {
    newStreak = current.currentStreak;
  } else if (current.lastPracticedDate === yesterday) {
    newStreak = current.currentStreak + 1;
  } else {
    newStreak = 1;
  }

  const weeklyLog = { ...current.weeklyLog };
  weeklyLog[today] = (weeklyLog[today] ?? 0) + wordCount;

  const cutoff = new Date(now.getTime() - 6 * 24 * 60 * 60 * 1000);
  const cutoffKey = dateKey(cutoff);
  for (const key of Object.keys(weeklyLog)) {
    if (key < cutoffKey) delete weeklyLog[key];
  }

  await setDoc(activityRef(uid), { currentStreak: newStreak, lastPracticedDate: today, weeklyLog });
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run src/lib/dailyActivity.test.ts`
Expected: all tests PASS.

- [ ] **Step 5: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/dailyActivity.ts apps/web/src/lib/dailyActivity.test.ts
git commit -m "feat(web): add dailyActivity — streak and weekly-log persistence"
```

---

## Task 3: `/dashboard` page

**Files:**
- Create: `apps/web/src/app/(app)/dashboard/page.tsx`
- Create: `apps/web/src/app/(app)/dashboard/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `computeLearningStats`, `MASTERED_INTERVAL_THRESHOLD` from `@/lib/learningStats` (Task 1); `getDailyActivity`, type `DailyActivity` from `@/lib/dailyActivity` (Task 2); `getVocabRecords` from `@/lib/vocabRecords` (existing).
- Produces: the `/dashboard` route the sidebar already links.

### Context

Read `apps/web/src/app/(app)/practice/page.tsx` (for the `getVocabRecords`-on-mount + auth-gate pattern to mirror — this page needs no `useSearchParams()`/`<Suspense>`, since it takes no URL params) and the approved mockup's structure (streak banner → 2 stat cards → CTA button → CEFR breakdown card → 7-day chart card). No English-only gate — this page works regardless of `targetLanguage`.

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/app/(app)/dashboard/page.test.tsx`:

```tsx
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
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/dashboard/page.test.tsx"`
Expected: FAIL — the page doesn't exist yet.

- [ ] **Step 3: Implement the page**

Create `apps/web/src/app/(app)/dashboard/page.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { computeLearningStats, type LearningStats } from "@/lib/learningStats";
import { getDailyActivity, type DailyActivity } from "@/lib/dailyActivity";

const CEFR_LEVELS: VocabRecord["cefrLevel"][] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const CHART_DAYS = 7;

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

const WEEKDAY_LABELS_MON_FIRST = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];

function weekdayLabel(key: string): string {
  const d = new Date(`${key}T00:00:00`);
  const jsDay = d.getDay(); // 0 = Sunday
  const monFirstIndex = jsDay === 0 ? 6 : jsDay - 1;
  return WEEKDAY_LABELS_MON_FIRST[monFirstIndex];
}

export default function DashboardPage() {
  const { user, loading: authLoading } = useAuthUser();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [activity, setActivity] = useState<DailyActivity | null>(null);
  const [activityError, setActivityError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    getVocabRecords(user.uid)
      .then(setRecords)
      .catch(() => setRecords([]));
    getDailyActivity(user.uid)
      .then(setActivity)
      .catch((err: unknown) => setActivityError(err instanceof Error ? err.message : String(err)));
  }, [user]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Tổng quan</h2>
        <p className="scr-sub">Đăng nhập để xem tiến độ học tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (records === null) return <p>Đang tải…</p>;

  const stats: LearningStats = computeLearningStats(records);
  const totalForChart = stats.totalCount;

  return (
    <div>
      <h2 className="scr-title">Tổng quan</h2>
      <p className="scr-sub">Tiến độ học tập của bạn, cập nhật theo thời gian thực.</p>

      {activityError && <p role="alert">Không tải được dữ liệu streak: {activityError}</p>}

      {activity && (
        <div className="dash-streak-banner">
          {activity.currentStreak > 0 ? (
            <>
              <span className="dash-streak-emoji">🔥</span>
              <div>
                <div className="dash-streak-count">{activity.currentStreak}</div>
                <div className="dash-streak-sub">ngày liên tiếp</div>
              </div>
            </>
          ) : (
            <>
              <span className="dash-streak-emoji">❄️</span>
              <div>
                <div className="dash-streak-sub">Chưa có streak — luyện gì đó để bắt đầu!</div>
              </div>
            </>
          )}
        </div>
      )}

      <div className="dash-stat-grid">
        <div className="dash-stat-card">
          <div className="dash-stat-label">Hôm nay</div>
          <div className="dash-stat-value">{stats.dueCount}</div>
          <div className="dash-stat-foot">từ đến hạn ôn tập</div>
        </div>
        <div className="dash-stat-card">
          <div className="dash-stat-label">Đã thuộc</div>
          <div className="dash-stat-value">{stats.masteredCount}</div>
          <div className="dash-stat-foot">/ {stats.totalCount} từ</div>
        </div>
      </div>

      {stats.dueCount > 0 && (
        <Link href="/practice?action=start" role="link" className="btn-primary dash-cta">
          Ôn {stats.dueCount} từ ngay <span aria-hidden="true">→</span>
        </Link>
      )}

      <div className="dash-card">
        <h3>Theo cấp độ CEFR</h3>
        <div className="dash-cefr-rows">
          {CEFR_LEVELS.map((level) => {
            const count = stats.cefrBreakdown[level];
            const pct = totalForChart === 0 ? 0 : (count / totalForChart) * 100;
            return (
              <div key={level} className="dash-cefr-row">
                <span className="dash-cefr-tag">{level.toUpperCase()}</span>
                <div className="dash-cefr-track">
                  <div className="dash-cefr-fill" style={{ width: `${pct}%` }} />
                </div>
                <span className="dash-cefr-count">{count}</span>
              </div>
            );
          })}
        </div>
      </div>

      {activity && (
        <div className="dash-card">
          <h3>7 ngày gần đây</h3>
          <div className="dash-chart">
            {lastNDays(CHART_DAYS).map((key) => {
              const value = activity.weeklyLog[key] ?? 0;
              const max = Math.max(...lastNDays(CHART_DAYS).map((k) => activity.weeklyLog[k] ?? 0), 1);
              const pct = value === 0 ? 4 : Math.max(10, (value / max) * 100);
              const isToday = key === dateKey(new Date());
              return (
                <div key={key} className={`dash-chart-col${isToday ? " today" : ""}`}>
                  <div className="dash-chart-bar-wrap">
                    <div className="dash-chart-bar" style={{ height: `${pct}%` }}>
                      <span className="dash-chart-value">{value}</span>
                    </div>
                  </div>
                  <div className="dash-chart-day">{weekdayLabel(key)}</div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Add the dashboard CSS**

In `apps/web/src/styles/bloom.css`, add at the end of the file:

```css
.dash-streak-banner {
  display: flex;
  align-items: center;
  gap: 16px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 20px;
  padding: 18px 20px;
  margin-bottom: 16px;
}
.dash-streak-emoji {
  font-size: 2.2rem;
  line-height: 1;
}
.dash-streak-count {
  font-size: 1.6rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.dash-streak-sub {
  color: var(--ink-soft);
  font-size: 0.88rem;
}

.dash-stat-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
  margin-bottom: 16px;
}
.dash-stat-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 16px 18px;
}
.dash-stat-label {
  font-size: 0.76rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--ink-faint);
}
.dash-stat-value {
  font-size: 2rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.dash-stat-foot {
  font-size: 0.8rem;
  color: var(--ink-soft);
}

.dash-cta {
  display: block;
  width: 100%;
  text-align: center;
  margin-bottom: 16px;
  text-decoration: none;
}

.dash-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 18px 20px;
  margin-bottom: 16px;
}
.dash-card h3 {
  margin: 0 0 14px;
  font-size: 1rem;
}

.dash-cefr-rows { display: flex; flex-direction: column; gap: 10px; }
.dash-cefr-row { display: grid; grid-template-columns: 32px 1fr 40px; align-items: center; gap: 10px; }
.dash-cefr-tag { font-size: 0.72rem; font-weight: 800; color: var(--ink-soft); }
.dash-cefr-track { height: 8px; border-radius: 999px; background: var(--surface-3); overflow: hidden; }
.dash-cefr-fill { height: 100%; background: var(--accent); border-radius: 999px; }
.dash-cefr-count { font-size: 0.78rem; color: var(--ink-soft); text-align: right; font-variant-numeric: tabular-nums; }

.dash-chart {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  align-items: end;
  gap: 8px;
  height: 120px;
}
.dash-chart-col { display: flex; flex-direction: column; align-items: center; height: 100%; gap: 6px; }
.dash-chart-bar-wrap { flex: 1; display: flex; align-items: flex-end; width: 100%; justify-content: center; }
.dash-chart-bar { width: 60%; max-width: 24px; border-radius: 6px 6px 2px 2px; background: var(--surface-3); position: relative; }
.dash-chart-col.today .dash-chart-bar { background: var(--accent); }
.dash-chart-value { position: absolute; top: -18px; font-size: 0.7rem; font-weight: 700; color: var(--ink-soft); left: 50%; transform: translateX(-50%); white-space: nowrap; }
.dash-chart-day { font-size: 0.7rem; color: var(--ink-faint); font-weight: 600; }
.dash-chart-col.today .dash-chart-day { color: var(--accent); font-weight: 800; }
```

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/dashboard/page.test.tsx"`
Expected: all tests PASS.

- [ ] **Step 6: Typecheck and build**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

Run: `cd apps/web && npm run build`
Expected: clean build, `/dashboard` statically prerendered.

- [ ] **Step 7: Commit**

```bash
git add "apps/web/src/app/(app)/dashboard/page.tsx" "apps/web/src/app/(app)/dashboard/page.test.tsx" apps/web/src/styles/bloom.css
git commit -m "feat(web): add the Tổng quan (Dashboard) page"
```

---

## Task 4: `/practice` — `?action=start` auto-trigger and daily-activity integration

**Files:**
- Modify: `apps/web/src/app/(app)/practice/page.tsx`
- Modify: `apps/web/src/app/(app)/practice/page.test.tsx`

**Interfaces:**
- Consumes: `recordDailyActivity` from `@/lib/dailyActivity` (Task 2).
- Produces: nothing new consumed by other tasks — this is the last piece `/dashboard`'s CTA link depends on.

### Context

Read `apps/web/src/app/(app)/practice/page.tsx` in full first — it currently has no `useSearchParams()`/`<Suspense>` wrapper at all (unlike every other URL-driven page in this app). Also read `apps/web/src/app/(app)/listening/dictation/page.tsx`'s existing `<Suspense>` wrapper (its outer default export) as the pattern to mirror for wrapping this page's content.

Two independent changes land in this one task since they touch the same file and the same result-reaching moment: (1) `?action=start` auto-starts a session using every currently-due word (not the picker's default 10-word cap); (2) the existing "batch SM-2 write on result phase" effect also fires `recordDailyActivity`.

- [ ] **Step 1: Write the failing tests**

Read `apps/web/src/app/(app)/practice/page.test.tsx` in full first for its existing mock/helper conventions, then add `vi.mock("@/lib/dailyActivity", () => ({ recordDailyActivity: vi.fn() }));` near its other `vi.mock` calls and a `useSearchParams`/`next/navigation` mock matching the pattern already used in `apps/web/src/app/(app)/listening/dictation/page.test.tsx` (read that file's mock block and mirror it — `pushMock`, `mockSearchParams`, `setSearchParams` helper). Add these tests:

```ts
  it("action=start auto-starts a session with ALL due words, ignoring the default word-count cap", async () => {
    mockSignedIn();
    setSearchParams({ action: "start" });
    const dueWords = Array.from({ length: 15 }, (_, i) => makeRecord({ id: `due-${i}`, nextReviewAt: null }));
    vi.mocked(getVocabRecords).mockResolvedValue(dueWords);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    // Session phase reached directly (skipped the setup picker), showing
    // progress through however many due words were selected — must be 15,
    // not capped to the picker's own default of 10.
    await screen.findByText("Từ 1 / 15");
  });

  it("does nothing when action is absent — manual picker flow is unchanged", async () => {
    mockSignedIn();
    setSearchParams({});
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", nextReviewAt: null })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    expect(await screen.findByRole("button", { name: "Bắt đầu" })).toBeInTheDocument();
  });

  it("action=start with zero eligible words falls through to the normal setup screen", async () => {
    mockSignedIn();
    setSearchParams({ action: "start" });
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    expect(await screen.findByRole("button", { name: "Bắt đầu" })).toBeInTheDocument();
  });

  it("records daily activity with the number of words graded once the result phase is reached", async () => {
    mockSignedIn();
    setSearchParams({});
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", nextReviewAt: null }),
      makeRecord({ id: "2", nextReviewAt: null }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));

    // Each flashcard must be flipped (click the card) before its grade
    // buttons ("Chưa hiểu"/"Đã hiểu", quality 1/5) are clickable — mirrors
    // this file's own existing grading tests exactly.
    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));
    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));

    await waitFor(() => expect(recordDailyActivity).toHaveBeenCalledWith("u1", 2));
  });
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/practice/page.test.tsx"`
Expected: FAIL — `action=start` isn't handled yet, `recordDailyActivity` isn't called yet.

- [ ] **Step 3: Wrap the page in `<Suspense>` and add the auto-trigger effect**

In `apps/web/src/app/(app)/practice/page.tsx`, rename the default export to an inner content component and add the `Suspense` wrapper, matching this file's own existing top-level structure. Find:

```tsx
import { useEffect, useRef, useState } from "react";
```

Replace with:

```tsx
import { Suspense, useEffect, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { recordDailyActivity } from "@/lib/dailyActivity";
```

Find:

```tsx
export default function PracticePage() {
  const { user, loading: authLoading } = useAuthUser();
```

Replace with:

```tsx
function PracticePageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const searchParams = useSearchParams();
  const action = searchParams.get("action");
  const autoStartTriggeredRef = useRef(false);
```

Find the existing `useEffect` that fetches records/topics:

```tsx
  useEffect(() => {
    if (!user) return;
    setLoadError(null);
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setLoadError(err instanceof Error ? err.message : String(err)));
  }, [user]);
```

Add a new effect right after it that handles `action=start` once records have loaded:

```tsx
  useEffect(() => {
    if (action !== "start" || !records || autoStartTriggeredRef.current) return;
    autoStartTriggeredRef.current = true;
    // Every currently-due word, not the picker's own default 10-word cap —
    // the dashboard's "Ôn N từ ngay" button promises exactly N words.
    const words = selectSessionWords(records, { topicIds: new Set(), maxCefr: null, count: null });
    if (words.length === 0) return;
    setSessionWords(words);
    setCurrentIndex(0);
    setSessionResults([]);
    sm2WrittenRef.current = false;
    setPhase("session");
  }, [action, records]);
```

- [ ] **Step 4: Add the `recordDailyActivity` call to the existing result-phase effect**

Find the existing SM-2 batch-write effect:

```tsx
  useEffect(() => {
    if (phase !== "result" || sm2WrittenRef.current || !user) return;
    sm2WrittenRef.current = true;
    const now = new Date();
    const updatedFieldsById = new Map<string, Sm2Fields>();
    for (const result of sessionResults) {
      const record = sessionWords.find((w) => w.id === result.vocabRecordId);
      if (!record) continue;
      const fields = computeSm2(record, result.quality, now);
      updatedFieldsById.set(result.vocabRecordId, fields);
      updateVocabRecordSm2(user.uid, result.vocabRecordId, fields).catch((err: unknown) => {
        console.error("Failed to save SM-2 result", err);
      });
    }
```

Replace with (one new block added right after `sm2WrittenRef.current = true;`):

```tsx
  useEffect(() => {
    if (phase !== "result" || sm2WrittenRef.current || !user) return;
    sm2WrittenRef.current = true;
    recordDailyActivity(user.uid, sessionResults.length).catch((err: unknown) => {
      console.error("Failed to record daily activity", err);
    });
    const now = new Date();
    const updatedFieldsById = new Map<string, Sm2Fields>();
    for (const result of sessionResults) {
      const record = sessionWords.find((w) => w.id === result.vocabRecordId);
      if (!record) continue;
      const fields = computeSm2(record, result.quality, now);
      updatedFieldsById.set(result.vocabRecordId, fields);
      updateVocabRecordSm2(user.uid, result.vocabRecordId, fields).catch((err: unknown) => {
        console.error("Failed to save SM-2 result", err);
      });
    }
```

- [ ] **Step 5: Add the `<Suspense>` wrapper at the bottom of the file**

Find the end of the (now-renamed) content component — its final closing brace before the file ends — and add the new default export right after it:

```tsx
export default function PracticePage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <PracticePageContent />
    </Suspense>
  );
}
```

- [ ] **Step 6: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/practice/page.test.tsx"`
Expected: all tests PASS, including every pre-existing test (the manual picker flow must be completely unaffected).

- [ ] **Step 7: Typecheck and build**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

Run: `cd apps/web && npm run build`
Expected: clean build, `/practice` still statically prerendered with no missing-Suspense-boundary error.

- [ ] **Step 8: Commit**

```bash
git add "apps/web/src/app/(app)/practice/page.tsx" "apps/web/src/app/(app)/practice/page.test.tsx"
git commit -m "feat(web): auto-start due-words sessions via /practice?action=start, record daily activity"
```

---

## Task 5: Daily-activity integration into the 6 remaining result pages

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx` + its test file
- Modify: `apps/web/src/app/(app)/reading/part5/page.tsx` + its test file
- Modify: `apps/web/src/app/(app)/reading/part6/page.tsx` + its test file
- Modify: `apps/web/src/app/(app)/reading/part7/page.tsx` + its test file
- Modify: `apps/web/src/app/(app)/listening/dictation/page.tsx` + its test file
- Modify: `apps/web/src/app/(app)/listening/comprehension/page.tsx` + its test file

**Interfaces:**
- Consumes: `recordDailyActivity` from `@/lib/dailyActivity` (Task 2).
- Produces: nothing new — this is the last task in the plan.

### Context

These 6 pages reach their result phase in 2 different existing shapes — match whichever shape each file already uses, don't force one pattern onto all 6:

- **`bilingual`, `part5`, `part6`, `part7`**: none of these currently have any "fires once when result phase is reached" effect (they have zero SM-2 impact, confirmed by this project's own prior final reviews) — each needs a **new** small effect+ref pair added.
- **`dictation`, `comprehension`**: `dictation/page.tsx` already calls `setPhase("result")` inside an async `handleSubmit` function that also does its own SM-2 work inline (not via an effect) — add the new call inline, right alongside. `comprehension/page.tsx`'s `handleSubmit` is sync and does no SM-2 work at all — add the new call there directly.

For each of the 6 files: read it first to confirm the exact current line numbers/shape haven't drifted from what's shown below (they shouldn't have, but this task depends on nothing else in this plan touching these files), then apply the matching change.

- [ ] **Step 1: `reading/bilingual/page.tsx`**

Read the file in full first — the `setPhase("result")` call is inside the sentence-completion handler (not a dedicated `handleSubmit`), and `passage` is the `ReadingPassage | null` state holding `.vocabIds`.

Add the import:

```ts
import { recordDailyActivity } from "@/lib/dailyActivity";
```

Add a new ref near the component's other `useRef` declarations:

```ts
  const dailyActivityRecordedRef = useRef(false);
```

Add a new effect right after the component's other `useEffect` hooks (before the `handleSubmit`-equivalent function definition):

```tsx
  useEffect(() => {
    if (phase !== "result" || dailyActivityRecordedRef.current || !user || !passage) return;
    dailyActivityRecordedRef.current = true;
    recordDailyActivity(user.uid, passage.vocabIds.length).catch((err: unknown) => {
      console.error("Failed to record daily activity", err);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);
```

Add a test to this page's test file: mock `recordDailyActivity`, complete a full session (every existing "complete the passage" test already does this), and assert `recordDailyActivity` was called with `(uid, passage.vocabIds.length)` once the result phase is reached — read the file's existing "reaches the result phase" test first and extend it rather than duplicating the whole setup.

- [ ] **Step 2: `reading/part5/page.tsx`**

Read the file in full first — `set: Part5Set | null` holds `.questions`, and `setPhase("result")` fires directly from the submit button's `onClick`.

Add the import and ref (same as Step 1), then add this effect:

```tsx
  useEffect(() => {
    if (phase !== "result" || dailyActivityRecordedRef.current || !user || !set) return;
    dailyActivityRecordedRef.current = true;
    recordDailyActivity(user.uid, set.questions.length).catch((err: unknown) => {
      console.error("Failed to record daily activity", err);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);
```

Add the matching test (mirroring Step 1's, with `set.questions.length` as the expected count).

- [ ] **Step 3: `reading/part6/page.tsx`**

Read the file in full first — `set: Part6Set | null` holds `.passages`, and the total blank count is `(set?.passages.length ?? 0) * QUESTIONS_PER_PASSAGE` (the same expression this file's own result-phase render block already computes as `total`).

Add the import and ref, then add this effect:

```tsx
  useEffect(() => {
    if (phase !== "result" || dailyActivityRecordedRef.current || !user || !set) return;
    dailyActivityRecordedRef.current = true;
    recordDailyActivity(user.uid, set.passages.length * QUESTIONS_PER_PASSAGE).catch((err: unknown) => {
      console.error("Failed to record daily activity", err);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);
```

Add the matching test.

- [ ] **Step 4: `reading/part7/page.tsx`**

Read the file in full first — `set: Part7Set | null` holds `.passageGroups`, and this file already exports a `totalQuestions(groups)` helper function (used elsewhere in the same file) that sums `questions.length` across all groups.

Add the import and ref, then add this effect:

```tsx
  useEffect(() => {
    if (phase !== "result" || dailyActivityRecordedRef.current || !user || !set) return;
    dailyActivityRecordedRef.current = true;
    recordDailyActivity(user.uid, totalQuestions(set.passageGroups)).catch((err: unknown) => {
      console.error("Failed to record daily activity", err);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);
```

Add the matching test.

- [ ] **Step 5: `listening/dictation/page.tsx`**

Read the file in full first — `handleSubmit` is an async function that already does its own inline SM-2 work after `setPhase("result")`. Add the import, then find:

```ts
    setDurationMs(duration);
    setFinalScore(score);
    setPhase("result");

    if (!user) return;
```

Replace with:

```ts
    setDurationMs(duration);
    setFinalScore(score);
    setPhase("result");

    if (!user) return;
    recordDailyActivity(user.uid, item.vocabIds.length).catch((err: unknown) => {
      console.error("Failed to record daily activity", err);
    });
```

Add a test asserting `recordDailyActivity` is called with `(uid, item.vocabIds.length)` when `handleSubmit` completes a session — extend this file's existing submit test rather than duplicating setup.

- [ ] **Step 6: `listening/comprehension/page.tsx`**

Read the file in full first — `handleSubmit` is a sync function with no SM-2 work at all. Add the import, then find:

```ts
  function handleSubmit() {
    if (!passage) return;
    audio.stop();
    const score = scoreComprehension(passage, selectedAnswers);
    setFinalScore(score);
    setPhase("result");
  }
```

Replace with:

```ts
  function handleSubmit() {
    if (!passage) return;
    audio.stop();
    const score = scoreComprehension(passage, selectedAnswers);
    setFinalScore(score);
    setPhase("result");
    if (user) {
      recordDailyActivity(user.uid, passage.questions.length).catch((err: unknown) => {
        console.error("Failed to record daily activity", err);
      });
    }
  }
```

Add a test asserting `recordDailyActivity` is called with `(uid, passage.questions.length)` when `handleSubmit` runs.

- [ ] **Step 7: Run every touched test file**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx" "src/app/(app)/reading/part5/page.test.tsx" "src/app/(app)/reading/part6/page.test.tsx" "src/app/(app)/reading/part7/page.test.tsx" "src/app/(app)/listening/dictation/page.test.tsx" "src/app/(app)/listening/comprehension/page.test.tsx"`
Expected: all PASS, including every pre-existing test in these 6 files.

- [ ] **Step 8: Typecheck, full suite, and build**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

Run: `cd apps/web && npm test -- --run`
Expected: all pass except the one known pre-existing unrelated `src/styles/bloom.test.ts` failure — if that file no longer fails (it shouldn't, since the `.app-frame` design was locked as permanent this session), treat that as a good sign, not a problem.

Run: `cd apps/web && npm run build`
Expected: clean build, all routes including `/dashboard`, `/practice`, and the 6 modified pages statically prerendered.

- [ ] **Step 9: Commit**

```bash
git add "apps/web/src/app/(app)/reading/bilingual/page.tsx" "apps/web/src/app/(app)/reading/bilingual/page.test.tsx" "apps/web/src/app/(app)/reading/part5/page.tsx" "apps/web/src/app/(app)/reading/part5/page.test.tsx" "apps/web/src/app/(app)/reading/part6/page.tsx" "apps/web/src/app/(app)/reading/part6/page.test.tsx" "apps/web/src/app/(app)/reading/part7/page.tsx" "apps/web/src/app/(app)/reading/part7/page.test.tsx" "apps/web/src/app/(app)/listening/dictation/page.tsx" "apps/web/src/app/(app)/listening/dictation/page.test.tsx" "apps/web/src/app/(app)/listening/comprehension/page.tsx" "apps/web/src/app/(app)/listening/comprehension/page.test.tsx"
git commit -m "feat(web): record daily activity from the 6 remaining result screens"
```
