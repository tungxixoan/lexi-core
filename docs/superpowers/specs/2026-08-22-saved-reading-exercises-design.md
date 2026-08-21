# Saved Reading Exercises (Đọc & gõ pilot) — Design

## Goal

Let users reuse a previously AI-generated Đọc & gõ passage instead of always waiting on a fresh AI call. This is a pilot: the architecture is generic enough to extend to Part 5/6/7 and Nghe chép/hiểu later, but this spec covers **only Đọc & gõ, web only**. Flutter and the other five exercise types are explicitly out of scope — see "Deferred" below.

## Background

Investigated during brainstorming (2026-08-22): no exercise-content persistence exists anywhere in this codebase, on either platform. Flutter's Part 5/6/7 and both Nghe types (`lib/features/reading/**`, `lib/features/listening/**`) generate fresh via Gemini every session and discard on reset — same as the web's Đọc & gõ today. The only precedent for per-user Firestore persistence is `users/{uid}/vocab_records` and `users/{uid}/topics`.

## Data model

New Firestore subcollection: `users/{uid}/reading_exercises/{exerciseId}`.

```ts
export interface SavedExerciseFilters {
  topicIds: string[];
  maxCefr: VocabRecord["cefrLevel"] | null;
  wordCount: number | null; // null = "Tất cả" was selected at generation time
}

export interface SavedReadingExercise {
  id: string;
  type: "bilingual"; // discriminant, for future Part5/6/7/Nghe types — not read yet, just future-proofing the schema
  passage: ReadingPassage; // { sentences: BilingualSentence[], vocabIds: string[] } — unchanged shape from readingPassage.ts
  generationFilters: SavedExerciseFilters; // the setup-screen filters active when this was generated
  targetLanguage: TargetLanguage;
  createdAt: string; // ISO
}
```

New file `apps/web/src/lib/savedReadingExercises.ts`:

```ts
export async function saveReadingExercise(
  uid: string,
  passage: ReadingPassage,
  generationFilters: SavedExerciseFilters,
  targetLanguage: TargetLanguage
): Promise<string>; // returns the new doc id

export async function getRandomSavedExercise(
  uid: string,
  targetLanguage: TargetLanguage,
  filters: SavedExerciseFilters,
  excludeId?: string
): Promise<SavedReadingExercise | null>;

export async function getAllUsedVocabIds(uid: string): Promise<Set<string>>;
```

`practiceSession.ts`'s `CEFR_ORDER` constant is exported (currently module-private) so `savedReadingExercises.ts` can reuse the same CEFR ordering instead of redefining it.

Firestore security rules live outside this repo (Console-managed, no `firestore.rules` file checked in) — `vocab_records` and `topics` already work as sibling `users/{uid}` subcollections with no per-collection rule file change needed here, so `reading_exercises` is expected to inherit the same per-owner rule automatically. The implementation plan should include a quick manual verification (write + read as the signed-in test user) rather than assuming this silently.

## Matching semantics ("lấy bài có sẵn" — loose matching)

Word identity (`vocabIds`) is **never** a matching or eligibility criterion — only the exercise's own stored `generationFilters` are compared against the setup screen's *current* filter selection:

- **`targetLanguage`**: exact match, required (a passage in the wrong learning language is never useful).
- **Topic**: if the current filter's `topicIds` is empty → matches anything. Otherwise, the saved exercise's `generationFilters.topicIds` must share **at least one** id with the current selection (array intersection, not equality).
- **Level**: if the current filter's `maxCefr` is `null` → matches anything. Otherwise, the saved exercise's `generationFilters.maxCefr` must be non-null **and** `CEFR_ORDER.indexOf(saved) <= CEFR_ORDER.indexOf(current)` (saved level at or below the requested cap — a saved exercise generated with no cap at all does not automatically qualify, since it isn't guaranteed to be within the now-requested cap).
- **Word count**: exact equality between the saved exercise's `generationFilters.wordCount` and the current filter's `wordCount` (both nullable; `null` only matches `null`).

Implementation: Firestore query filters only on `targetLanguage == targetLanguage` (a plain equality Firestore can do natively); everything else is filtered client-side in JS over that result set — consistent with how `getVocabRecords`/`selectSessionWords` already fetch broadly and filter/shuffle client-side elsewhere in this codebase. No composite index needed. From the surviving candidates (minus `excludeId` if given), pick one via `Math.random()`; return `null` if the candidate list is empty.

The "Từ vựng dùng trong bài" list on the result screen is unrelated to this matching logic — it's pure display, degrading gracefully by filtering `passage.vocabIds` against whatever `VocabRecord`s still exist today (identical to the current, already-shipped behavior), regardless of whether the session is `"generated"` or `"reused"`.

## Word-priority for AI generation ("ưu tiên từ chưa dùng")

When the AI-generate flow builds its word list, words that have **never appeared in any of the user's saved exercises** are preferred over words that have, so repeated AI generation doesn't keep reusing the same easy-to-match words while others never get saved:

```ts
export function prioritizeUnusedWords(words: VocabRecord[], usedVocabIds: Set<string>): VocabRecord[] {
  const unused = words.filter((w) => !usedVocabIds.has(w.id));
  const used = words.filter((w) => usedVocabIds.has(w.id));
  return [...unused, ...used];
}
```

`handleGenerate()` changes from directly truncating `selectSessionWords(records, filters)` to:

```ts
const pool = selectSessionWords(records, { ...filters, count: null }); // due-prioritized, shuffled, untruncated
const usedVocabIds = await getAllUsedVocabIds(user.uid);
const prioritized = prioritizeUnusedWords(pool, usedVocabIds);
const words = filters.count === null ? prioritized : prioritized.slice(0, filters.count);
```

`selectSessionWords` itself (shared with Ôn tập/Practice) is **not modified** — this layers on top by calling it with `count: null` and truncating afterward, so Ôn tập's behavior is untouched. Only *saved* exercises count toward `usedVocabIds` — an unsaved, freshly-generated-but-abandoned passage from earlier in the same session doesn't count.

## UI — setup screen

Two buttons:

- **"Tạo bài luyện"** (existing, unchanged label) — gated by the existing "≥5 matching words" rule, since AI generation needs that many live vocab words right now to build a prompt from. Calls the AI, using the word-priority logic above. Session starts with `sessionMode: "generated"`.
- **"🔀 Lấy bài có sẵn"** (new) — **not** gated by the 5-word rule, since the primary path never touches live vocab count. Calls `getRandomSavedExercise` with the current filters.
  - Found → starts the session directly from the saved passage (no AI call, no live-vocab dependency at all). `sessionMode: "reused"`.
  - Not found → falls back to AI generation, which *does* need the 5-word rule:
    - ≥5 matching words → shows an inline note next to the button ("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…") and immediately runs the same AI-generate path as "Tạo bài luyện". `sessionMode: "generated"` (not `"reused"` — the fallback is a full generate, not a partial reuse).
    - <5 matching words → shows the existing "chưa đủ từ khớp bộ lọc" hint instead of attempting a doomed AI call.

Both buttons show an in-progress label while their request is in flight (mirrors the existing "Đang tạo bài…" state already on "Tạo bài luyện"). The exact plan/task will pin down the precise JSX and state variables — this section fixes the *behavior*, not the literal code.

## UI — result screen

New page state: `sessionMode: "generated" | "reused"`, set once when a session starts and carried through to the result screen.

- **"Lưu bài" button** (new) — visible only when `sessionMode === "generated"` and the current session hasn't been saved yet. Calls `saveReadingExercise`, then disables itself and shows a saved state (mirrors the `bulkSaving` disable-while-in-flight pattern already used in `VocabSuggestionsSection`). Remembers the new doc's id as `justSavedId`.
- **`VocabSuggestionsSection`** — rendered only when `sessionMode === "generated"`. Hidden entirely for `"reused"` sessions.
- **"Sinh bài mới" button** — **behavior change from what's currently shipped.** Today this button always resets to the setup phase (no auto-regenerate). Per this spec it instead replays whichever mode the session started in, without returning to setup:
  - `"generated"` → calls the AI-generate flow again directly (same as setup's "Tạo bài luyện", including word-priority). Still needs ≥5 live matching words; if that's no longer true (e.g. words got deleted since setup), falls back to resetting to the setup phase so the existing "chưa đủ từ" hint explains why, instead of attempting a doomed AI call from the result screen.
  - `"reused"` → calls `getRandomSavedExercise` again, passing `excludeId: justSavedId` if the just-finished session was saved during this visit (so the freshly-saved exercise isn't immediately handed back). No match → same inline-note-then-AI-fallback as the setup screen's "Lấy bài có sẵn" (including its own ≥5-words check and setup-phase fallback), and `sessionMode` flips to `"generated"` for that new session if the AI path runs.

## Error handling

- Firestore errors on save or random-fetch surface via `role="alert"`, matching the rest of the page — never a blank screen.
- Double-clicking "Lưu bài" is guarded by an in-flight boolean disabling the button, same pattern as `VocabSuggestionsSection`'s `bulkSaving`.
- No cap or cleanup on saved-exercise count per user — per-user volume is expected to stay small; deferred as unnecessary for a first version (YAGNI).

## Deferred (explicitly out of scope for this spec)

- Part 5/6/7 and Nghe chép/hiểu — none of these exist yet on web; each gets its own future spec, built with saved-exercise support from day one (no retrofit needed) using this same `type`-discriminated schema shape.
- Flutter — ported as its own follow-up spec once the web pilot is live, reusing the Firestore schema decided here.
- Any cap/expiry/cleanup policy on `reading_exercises` growth.
- Any change to `selectSessionWords`'s own behavior (Ôn tập/Practice is untouched).
