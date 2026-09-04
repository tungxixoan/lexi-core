# SP-7: AI exercise types on the web Practice screen

**Date:** 2026-09-04
**Status:** approved (autonomous execution per user instruction "Chạy tuần tự đến SP cuối cùng không cần hỏi lại")

## Problem

The Flutter SM-2 practice session mixes four exercise types per word
(`lib/features/practice/`): **flashcard**, **multiple_choice**,
**fill_in_blank**, **translation** — the last three AI-generated (BYOK),
picked by CEFR level. The React web Practice screen (`/practice`, "Ôn tập")
is **flashcard-only** — a deliberate "zero-AI" simplification made during
React Web Plan 3. The user now wants the web screen to match Flutter: same
four types, same picker logic, same self-graded translation.

This does NOT add a standalone "pick a drill type" screen — the user floated
that as an open question; it stays out of scope. The types remain mixed
randomly within one session, exactly as Flutter does it.

## What already exists on web (reuse, don't rebuild)

- `generateContent({provider, model, apiKeyCiphertext, prompt})` → `{text}` —
  the BYOK Cloud Function proxy, already used by Lookup / Reading / Listening.
- `parseAiJsonObject(text)` (`lib/parseAiJson.ts`) — strips fences / prose,
  returns the JSON object.
- `computeSm2(record, quality, now)` + the batch SM-2 write + `recordDailyActivity`
  in `practice/page.tsx`'s `phase === "result"` effect — **type-agnostic, unchanged**.
- `practice/page.tsx` session loop: `sessionWords`, `currentIndex`,
  `sessionResults: SessionGradeResult[]` (`{vocabRecordId, quality: 1 | 5}`),
  `handleGrade(quality)`.
- `settings.providers[settings.activeProvider].apiKeyCiphertext` — the
  AI-availability signal (same as Reading's `activeConfig.apiKeyCiphertext`).

## Design

### 1. `apps/web/src/lib/practiceExercise.ts` (new)

Port Flutter's `exercise.dart` + `ExerciseGeneratorSource` + `GenerateExerciseUseCase`:

```ts
export type PracticeExercise =
  | { type: "flashcard"; record: VocabRecord }
  | { type: "multiple_choice"; record: VocabRecord; question: string; options: string[]; correctIndex: number }
  | { type: "fill_in_blank"; record: VocabRecord; sentence: string; answer: string } // sentence has one "___"
  | { type: "translation"; record: VocabRecord; prompt: string; answer: string };

export function buildExercisePrompt(record: VocabRecord): string   // verbatim port of Flutter _buildPrompt
export function parseExercise(json: Record<string, unknown>, record: VocabRecord): PracticeExercise  // port of _parseExercise; unknown/malformed type → {type:"flashcard"}
export async function generateExercise(
  record: VocabRecord,
  ai: { provider: AiProvider; model: string; apiKeyCiphertext: string }
): Promise<PracticeExercise>   // generateContent → parseAiJsonObject → parseExercise; ANY throw → {type:"flashcard", record}
```

- `fill_in_blank.answer` stored `.toLowerCase().trim()` (matches Flutter).
- The prompt keeps Flutter's "Vietnamese script only" guard for `translation`.

### 2. `apps/web/src/lib/pickExercise.ts` (new) — port of Flutter `_pickExercise`

```ts
// Pure decision — the page does the async generateExercise call.
export function shouldUseFlashcard(record: VocabRecord, aiAvailable: boolean, rng: () => number = Math.random): boolean {
  if (record.sm2Repetitions === 0 || !aiAvailable) return true;
  return rng() < 0.30;
}
```

(`VocabRecord` on web already carries `sm2Repetitions` — verify the field
name; Flutter uses `sm2Repetitions`, web's `Sm2Fields` uses `sm2Repetitions`.)

### 3. Three card components (`apps/web/src/components/practice/`)

All: `{ exercise, onGrade }` where `onGrade: (quality: 1 | 5) => void`. Mirror
the Flutter widgets' UX and copy:

- **`MultipleChoiceCard.tsx`** — the question + 4 option buttons. On click:
  lock, show correct (green) + wrong-picked (red), then after ~800ms
  `onGrade(pickedIndex === correctIndex ? 5 : 1)`.
- **`FillInBlankCard.tsx`** — render `sentence.split("___")` with a blank
  slot; a text input + "Kiểm tra" button (also submit-on-Enter). On submit:
  compare `input.trim().toLowerCase() === answer` (answer already normalized),
  show ✓/✗ + (if wrong) "Đáp án: …", then after ~1200ms `onGrade(correct ? 5 : 1)`.
- **`TranslationCard.tsx`** — self-graded. Show `prompt` (strip the
  `"Translate to Vietnamese: "` / quotes prefix like Flutter does), a 2-line
  textarea, "Xem đáp án" (disabled until non-empty). After reveal: show
  "Đáp án: …" then two buttons "Sai rồi" / "Đúng rồi" → `onGrade(1)` / `onGrade(5)`.

CSS: add `.pe-*` (practice-exercise) rules to `apps/web/src/styles/bloom.css`,
consistent with the existing `.fc-*` flashcard + `.btn-primary/.btn-secondary`
idiom. Reuse `--accent`, `--success`, `--danger`, `--border` tokens.

### 4. `practice/page.tsx` wiring

- `aiAvailable = Boolean(settings?.providers[settings.activeProvider]?.apiKeyCiphertext)`.
- New state `exercises: (PracticeExercise | null)[]` parallel to `sessionWords`,
  reset to `Array(words.length).fill(null)` when a session starts (both
  `handleStart` and the `action === "start"` auto-start path).
- `generateAt(index)`: if `index >= sessionWords.length` or
  `exercises[index]` already set, return. If `shouldUseFlashcard(word, aiAvailable)`
  → set `{type:"flashcard", record: word}`. Else `await generateExercise(word, ai)`
  → set the result (already flashcard-on-error). Guard against a stale session
  (compare against a session token / check the word still matches) so a slow
  response from a previous session doesn't write into a new one.
- On session start: `generateAt(0)` awaited (show a spinner until
  `exercises[0]` is non-null), `generateAt(1)` fired without await.
- In `handleGrade`, after computing `nextResults`: if not the last word,
  after advancing to `currentIndex + 1`, call **only** `generateAt(currentIndex + 2)`.
  `currentIndex + 1` is already seeded (at session start for index 1, or by the
  previous grade), so re-firing it risks a duplicate in-flight `generateExercise`
  (wasted BYOK call) while its first request is still pending — the
  `exercisesRef` guard is `null` until the response lands. Matches Flutter's
  `practice_session_provider.dart` (`_generateAt(0)` + `_generateAt(1)` at start,
  then a single `_generateAt(nextIndex + 1)` per grade).
- `phase === "session"` render: `const ex = exercises[currentIndex]`. If
  `ex === null` → a small "Đang tạo bài tập…" spinner. Else switch on
  `ex.type`: `flashcard` → the existing `<FlashcardCard record={word} onGrade={handleGrade} />`,
  `multiple_choice` → `<MultipleChoiceCard exercise={ex} onGrade={handleGrade} />`,
  etc. Keep the `key={sessionWords[currentIndex].id}` remount so each word
  starts its card fresh.
- The progress row / track and the result screen are unchanged (grade quality
  is all they read).

### 5. Setup screen

No new controls. (Flutter's practice setup has no exercise-type control
either.) Optionally add one line to the `.scr-sub` copy noting that with an AI
key set, sessions mix in AI exercises — nice-to-have, not required.

## Non-goals

- No standalone drill-type-picker screen (either platform).
- No change to the SM-2 algorithm, the 30/70 flashcard mix, the `rep === 0`
  rule, or the batch-write-on-result flow.
- No change to Flutter (it already has all this).
- No offline caching of generated exercises (Flutter doesn't either — SP-5's
  "Lưu bài" is for reading/listening passages, not SM-2 drills).

## Testing

- `practiceExercise.test.ts`: `buildExercisePrompt` contains the word/meaning/CEFR;
  `parseExercise` handles each of the 4 shapes + an unknown `type` → flashcard +
  a missing-field payload → flashcard (no throw); `generateExercise` returns
  flashcard when `generateContent` rejects (mock it).
- `pickExercise.test.ts`: `rep === 0` → flashcard; `!aiAvailable` → flashcard;
  `rng` 0.2 → flashcard, 0.5 → not; deterministic with an injected `rng`.
- Each card component test: MC auto-grades correct/wrong; fill compares
  normalized; translation reveal gate + self-grade buttons call `onGrade`.
- `practice/page.test.tsx`: a session with a mocked `generateExercise`
  returning an MC exercise renders `MultipleChoiceCard` and grading it advances
  + writes SM-2 (existing assertions still hold); a mocked reject → flashcard
  still shown; `rep === 0` word → flashcard even with a key set.
- `npm run -w apps/web typecheck` clean, `npm test -w apps/web` green. Flutter
  untouched.
