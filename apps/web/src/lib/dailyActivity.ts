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
