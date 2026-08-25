# Tổng quan (Dashboard) on Web — Design

## Context

The web app's sidebar already links `/dashboard` ("🏠 Tổng quan"), but no route exists yet — it 404s. This is React Web Plan 3's deliberately-deferred Dashboard/streak phase. Flutter already ships the equivalent (Plan 5, "Daily Review + Progress Dashboard"), confirmed by reading the real source in full:

- `lib/features/practice/presentation/screens/progress_screen.dart` — the screen, reached via the practice hub's "Tiến độ học tập" card (not its own top-level tab on Flutter).
- `lib/features/practice/domain/entities/learning_stats.dart` — `LearningStats`: `dueCount`, `masteredCount`, `totalCount`, `cefrBreakdown` (per-level word count), `currentStreak`, `weeklyLog` (date-keyed word-count map).
- `lib/core/services/stats_service.dart` — `computeStats()` derives `dueCount`/`masteredCount`/`cefrBreakdown`/`totalCount` fresh from the vocab Hive box on every call (`masteredCount` = `sm2Interval >= 21`, no separately-tracked flag); `currentStreak`/`weeklyLog` are read from SharedPreferences. `recordPracticeSession(wordCount)`: if last-practiced date is today, streak unchanged; if yesterday, streak+1; otherwise streak resets to 1. Appends `wordCount` to today's entry in the weekly log (running total if called twice same day) and prunes entries older than 6 days ago.
- **`recordPracticeSession` is called from 7 result screens app-wide**, not just Ôn tập/Practice: `session_result_screen.dart` (Ôn tập), `reading_result_screen.dart` (Đọc & gõ), `part5_result_screen.dart`, `part6_result_screen.dart`, `part7_result_screen.dart`, `dictation_result_screen.dart` (Nghe chép), `comprehension_result_screen.dart` (Nghe hiểu) — confirmed by grep, not assumed. Streak is a whole-app daily-activity streak, not narrowly a spaced-repetition-review streak.

## Decision made during brainstorming

**Streak scope matches Flutter exactly**: counts activity from all 7 web equivalents (Đọc & gõ, Part 5/6/7, Nghe chép, Nghe hiểu, Ôn tập), not narrowed to Ôn tập alone — confirmed explicitly with the user, who understood the cost (7 existing result pages each need one new call added) versus the narrower alternative (1 file, but streak wouldn't match Flutter for a user on both platforms).

**Web wrinkle**: `apps/web/` has no local-storage layer analogous to Flutter's SharedPreferences — everything persists through Firestore. `dueCount`/`masteredCount`/`cefrBreakdown` need no new persistence (computed client-side from `VocabRecord[]`, already fetched via `getVocabRecords`, same source Flutter computes from). `currentStreak`/`weeklyLog` need a new small Firestore doc, mirroring `apps/web/src/lib/settings.ts`'s existing single-doc-per-user pattern (`users/{uid}/settings/config`) rather than inventing a new persistence shape.

## Architecture

### `apps/web/src/lib/learningStats.ts` (new — pure computation, no Firestore)

```ts
export interface LearningStats {
  dueCount: number;
  masteredCount: number;
  totalCount: number;
  cefrBreakdown: Record<VocabRecord["cefrLevel"], number>;
}

export const MASTERED_INTERVAL_THRESHOLD = 21; // matches stats_service.dart exactly

export function computeLearningStats(records: VocabRecord[], now: Date = new Date()): LearningStats
```

Ports `StatsService.computeStats()`'s due/mastered/CEFR logic exactly: a record is due when `nextReviewAt === null` or `nextReviewAt <= now`; mastered when `sm2Interval >= 21`; `cefrBreakdown` counts every record into its `cefrLevel` bucket (all 6 levels always present, defaulting to 0 — not just the levels that happen to appear, matching Flutter's `{for (final l in CEFRLevel.values) l: 0}` seeding). Takes an already-fetched `VocabRecord[]` — the dashboard page fetches via the existing `getVocabRecords`, same as every other page.

### `apps/web/src/lib/dailyActivity.ts` (new — Firestore persistence)

```ts
export interface DailyActivity {
  currentStreak: number;
  lastPracticedDate: string | null; // "yyyy-MM-dd", null = never practiced
  weeklyLog: Record<string, number>; // "yyyy-MM-dd" -> word count that day
}

export async function getDailyActivity(uid: string): Promise<DailyActivity>
export async function recordDailyActivity(uid: string, wordCount: number, now: Date = new Date()): Promise<void>
```

Backed by one document, `users/{uid}/stats/activity`, mirroring `settings.ts`'s exact read/write shape (`getSettings`/`saveSettings` → `getDailyActivity`/`recordDailyActivity`; a missing doc returns the same defaults as Flutter's first-ever launch: `{currentStreak: 0, lastPracticedDate: null, weeklyLog: {}}`).

`recordDailyActivity` ports `recordPracticeSession` exactly:
- Same-day repeat call: streak unchanged, `weeklyLog[today] += wordCount` (running total, not overwritten).
- Last practiced yesterday: streak + 1.
- Any other gap (including never having practiced): streak resets to 1.
- Prunes `weeklyLog` entries dated more than 6 days before today (keeps a rolling 7-day window: today + 6 prior days) — same cutoff rule as Flutter's `DateTime.now().subtract(const Duration(days: 6))`.
- `lastPracticedDate` is always set to today's date key after the call.

Both functions are called **best-effort** everywhere they're integrated (fire-and-forget with a `console.error` on failure) — matching how `updateVocabRecordSm2` is already called from every result screen in this app (a streak-write failure must never block a result screen from rendering).

### Integration: 7 result-screen call sites

Each of these pages gets one new `recordDailyActivity(user.uid, count)` call, fired once when that page's result phase is reached (mirroring exactly where Flutter's own 7 call sites fire, all inside a `WidgetsBinding.instance.addPostFrameCallback`-equivalent or the existing "runs once when this phase is reached" effect each page already has for its own SM-2/stats work):

| Page | `count` argument |
|---|---|
| `apps/web/src/app/(app)/practice/page.tsx` | `sessionResults.length` (words graded this session) |
| `apps/web/src/app/(app)/reading/bilingual/page.tsx` | the passage's `vocabIds.length` |
| `apps/web/src/app/(app)/reading/part5/page.tsx` | `questions.length` |
| `apps/web/src/app/(app)/reading/part6/page.tsx` | total blank count across the 3 passages |
| `apps/web/src/app/(app)/reading/part7/page.tsx` | total question count across all groups |
| `apps/web/src/app/(app)/listening/dictation/page.tsx` | `item.vocabIds.length` |
| `apps/web/src/app/(app)/listening/comprehension/page.tsx` | `questions.length` |

Exact current variable names in each file are confirmed by the implementation plan (each file must be read fresh, not assumed from this table) — the mapping above is the *semantic* intent (mirroring exactly what Flutter's own 7 screens pass), not literal code.

### `apps/web/src/app/(app)/dashboard/page.tsx` (new)

A top-level page (not nested under Ôn tập, unlike Flutter — the sidebar stub already treats it as a standalone destination). On mount, fetches `getVocabRecords(uid)` and `getDailyActivity(uid)` in parallel (same `Promise.all` pattern used elsewhere), computes `computeLearningStats(records)` client-side, and renders:

1. **Streak banner** — exactly 2 states, matching Flutter's own `progress_screen.dart` banner: 🔥 + streak count when `currentStreak > 0`; ❄️ + "Chưa có streak — luyện gì đó để bắt đầu!" when `currentStreak === 0`. No third/intermediate state.
2. **Two stat cards** — "Hôm nay" (`dueCount`) and "Đã thuộc" (`masteredCount`/`totalCount`).
3. **"Ôn N từ ngay" button** (N = `dueCount`), hidden/disabled when `dueCount === 0`. Navigates to `/practice?action=start`.
4. **CEFR breakdown** — 6 horizontal bars (A1→C2), each showing count and proportion of `totalCount`.
5. **7-day activity chart** — a hand-rolled CSS bar chart (no new charting dependency) built from `weeklyLog`, always showing exactly 7 columns (today + 6 prior days, zero-filled for days with no entry) in chronological order, with today's bar visually distinguished (matches the approved mockup).

### `/practice?action=start` auto-trigger (modifies the existing page)

`practice/page.tsx` currently has no `useSearchParams()`/`<Suspense>` wrapper at all (unlike every other URL-driven page in this app) and is a pure picker-then-manual-start flow. This task adds the standard wrapper plus one new effect: when `action=start` is present and `records` has loaded, override the local `wordCount` state to `null` ("Tất cả" — no truncation) *before* calling the existing `handleStart()`, so the auto-started session reviews every currently-due word, not just the default 10-word cap (otherwise a dashboard button reading "Ôn 15 từ ngay" could silently truncate to 10 if the picker's own default word-count setting were left in place). `selectedTopicIds`/`maxCefr` stay at their normal defaults (no filter) — `selectSessionWords`'s existing due-first-else-everything logic (already shipped, unmodified) does the rest. Without `action=start` in the URL, the page's behavior is completely unchanged.

## Error Handling

- `getDailyActivity` failure on the dashboard: the streak banner and 7-day chart show a Vietnamese inline error state (`role="alert"`) instead of the whole page failing — `dueCount`/`masteredCount`/CEFR breakdown still render normally, since they only depend on `getVocabRecords` (a separate, independent fetch).
- `recordDailyActivity` failure on any of the 7 integration points: silent, `console.error` only — never blocks or delays that page's result rendering, matching the existing `updateVocabRecordSm2` failure-handling precedent on every one of those pages already.
- `/practice?action=start` with zero eligible words (empty vocab bank): falls through to the existing setup-phase UI unchanged (the auto-trigger effect no-ops when `selectSessionWords` returns an empty array, mirroring `handleStart`'s own existing empty-array guard) — never navigates into a broken empty session.

## Testing

- `learningStats.ts`: unit tests mirroring `stats_service_test.dart`'s own cases exactly — empty records → all zeros; due-by-null vs due-by-past-date vs not-due; mastered-at-exactly-21 boundary (`sm2Interval: 20` not mastered, `21` mastered); CEFR breakdown counts every level including zero-count levels.
- `dailyActivity.ts`: unit tests mirroring `stats_service_test.dart`'s streak test exactly — same-day repeat call doesn't bump streak but does add to that day's log entry; consecutive-day call increments; a 2-day-or-more gap resets to 1; a first-ever call (`lastPracticedDate: null`) treated as a gap (resets/starts at 1, not a crash); weekly log pruning drops entries older than 6 days but keeps exactly-6-days-old ones.
- `dashboard/page.tsx`: language-agnostic (no English-only gate needed — this page works for any `targetLanguage`, unlike Nghe/some reading modes), renders all 5 sections from mocked `getVocabRecords`/`getDailyActivity`, "Ôn N từ ngay" button reflects the current `dueCount` and is absent/disabled at 0, navigates to the correct URL.
- `practice/page.tsx`: new tests for the `action=start` auto-trigger — auto-starts with all due words regardless of the default word-count cap, does nothing when `action` is absent (existing manual-start tests must keep passing unchanged), no-ops safely on zero eligible words.
- Each of the 6 other integration points: one test per page asserting `recordDailyActivity` is called with the correct count when that page's result phase is reached, and that a rejected `recordDailyActivity` promise doesn't block or alter the result screen's own rendering.
