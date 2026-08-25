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
    // Local (no "Z") timestamps: dateKey() extracts the calendar day from
    // local time (mirroring stats_service.dart's DateTime.now()-based
    // _dateKey), so these must be expressed in local time too. UTC
    // literals like "...T18:00:00.000Z" roll into the next local calendar
    // day in timezones ahead of UTC+6 (e.g. Asia/Saigon, UTC+7 — this
    // repo's own target timezone), which flips this into a cross-day case
    // and breaks the "same day" assertion below.
    await recordDailyActivity(UID, 5, new Date("2026-08-25T10:00:00.000"));
    await recordDailyActivity(UID, 3, new Date("2026-08-25T18:00:00.000"));
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
