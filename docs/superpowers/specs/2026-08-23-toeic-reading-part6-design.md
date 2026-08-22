# TOEIC Reading Part 6 — Design

## Goal

Bring Flutter's TOEIC Part 6 "Điền đoạn văn" (Text Completion) exercise to the React web app, as the third card on the `/reading` hub alongside Đọc & gõ and Part 5 — reusing the hub-driven, topic-filter, save/reuse architecture that already ships for both of those, not the older per-page-setup design an earlier spec sketched before that architecture existed.

## Background

Flutter's `lib/features/reading/{data/sources,domain/entities,presentation}/part6_*` is a complete, working, ephemeral (no persistence) implementation, read in full during brainstorming. It generates exactly 3 short business documents (email/memo/notice/advertisement/article), each with exactly 4 numbered inline blanks marked `(1)___`–`(4)___` in reading order, each blank carrying 4 options + a correct index + a Vietnamese explanation. At least one blank per passage must be a "select the sentence that best fits" item, where the 4 options are full candidate sentences instead of single words/phrases — verified against Flutter's actual session/result screens that this needs **no special UI treatment**: both blank types render through the identical radio-option widget.

An earlier spec (`docs/superpowers/specs/2026-08-22-toeic-reading-parts-567-design.md`) already sketched Part 6's architecture, but it predates two things that have since shipped and supersede it: Part 5 itself (with full save/reuse infrastructure, a generic `McQuestionCard` component, and a `savedReadingExercises.ts` discriminated union already built to grow into more Parts), and the "Reading Hub / Setup Merge" feature (`docs/superpowers/specs/2026-08-22-reading-hub-setup-merge-design.md`), which migrated Part 5's own "Chủ đề" filter from a fixed enum to real Vocab Bank topics and moved all setup UI (topic picker, mode picker, per-mode secondary filter, action buttons) onto the `/reading` hub itself — destination pages have no setup phase of their own anymore; they read filters + action from the URL on mount and auto-trigger. This spec builds Part 6 directly against that current architecture, not the older per-page-setup one.

## Architecture

**`apps/web/src/lib/part6.ts`** (new file, mirrors `apps/web/src/lib/part5.ts`'s shape exactly):

```ts
export interface Part6Question {
  options: string[]; // always 4 — words/phrases OR full candidate sentences
  correctIndex: number;
  explanation: string; // Vietnamese
}

export interface Part6Passage {
  passageText: string; // blanks inline, e.g. "... the office (1)___ Monday ..."
  questions: Part6Question[]; // always 4, ordered to match blank numbering
}

export interface Part6Set {
  passages: Part6Passage[]; // always 3
}

export function buildPart6Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string;
export function parsePart6Set(json: Record<string, unknown>): Part6Set;
```

`buildPart6Prompt` is ported from `part6_source.dart`'s prompt verbatim, with the same topic-names-not-enum adaptation Part 5 already made (`buildPart5Prompt(topicNames: string[], ...)`) and the same "Vietnamese-script-only explanations" clause every AI prompt in this app already carries. `parsePart6Set` is tolerant like `parsePart5Set` (never throws on malformed/missing fields, defaults to empty strings/arrays) but additionally drops any passage whose parsed `questions` array isn't exactly length 4 — mirroring Flutter's own `.where((p) => p.questions.length == 4)` filter — since a passage with the wrong blank count can't render against the fixed `(1)`–`(4)` labeling.

**`apps/web/src/lib/savedReadingExercises.ts`** gains one new union member:

```ts
| { id: string; type: "part6"; passage: Part6Set; generationFilters: ToeicFilters; targetLanguage: TargetLanguage; createdAt: string }
```

No function bodies change — `matchesToeic`, `FiltersFor`/`PassageFor`, and `getRandomSavedExercise`'s per-type dispatch are already generic over `SavedReadingExercise`'s member types, and Part 6 reuses `ToeicFilters` (`{ topicIds: string[]; volumes: string[] }`) unchanged, exactly as Part 5 does.

**Hub (`apps/web/src/app/(app)/reading/page.tsx`)**:
- `Mode` becomes `"bilingual" | "part5" | "part6"`.
- A third card: title `"📄 Part 6 — Điền đoạn văn"`, description `"3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống kiểu TOEIC."`.
- The volume-chip secondary filter block currently gated on `mode === "part5"` is now gated on `mode === "part5" || mode === "part6"` — both Parts share the identical `ECONOMY_VOLUMES`/`VOLUME_LABELS` chip UI, no new component.
- `buildQuery`'s `else if (mode === "part5")` branch becomes `else if (mode === "part5" || mode === "part6")` — both encode `topicIds` + `volumes` the same way; no new query parameter is introduced for Part 6.
- `navigate()`'s mode→path map gains `"part6" → "/reading/part6"`.
- `"Tạo bài luyện"` for Part 6 is never gated by word count, exactly like Part 5 (the `mode === "part5" || canGenerateBilingual` condition becomes `mode !== "bilingual" || canGenerateBilingual`).

**`apps/web/src/app/(app)/reading/part6/page.tsx`** (new file): structurally identical to `part5/page.tsx` — same `"use client"` + `Suspense`-wrapped `Part6PageContent` split, same `useSearchParams()`-derived `topicIds`/`volumes`/`action`, same `contextLoaded` gate (set via `.finally()` on the best-effort `Promise.all([getVocabRecords, getTopics])`) before the auto-trigger effect fires — required here for the same reason Part 5 needed it: `buildPart6Prompt` takes resolved topic *names*, so the effect must wait for `topics` to be populated before calling it. Same `triggeredRef`-guarded mount effect, same `handleGenerate`/`fetchSavedExercise`/`handleSaveExercise`/`handleNewSession` shape (Part 6 has no word-count precondition on `fetchSavedExercise`'s fallback, same as Part 5 — its "not found" path always falls through to `handleGenerate()` unconditionally). The only real differences from `part5/page.tsx` are: the import (`buildPart6Prompt`/`parsePart6Set`/`Part6Set` from `./part6`), the "part6" literal passed to `saveReadingExercise`/`getRandomSavedExercise`, and the session/result JSX (below).

## Session/result UI

Both the session and result phases loop `set.passages` (always 3, indices 0-2):
- A heading `"Đoạn {passageIndex + 1}"`.
- The full `passage.passageText` rendered as-is (blanks visible inline as literal `"(1)___"` etc. — no special formatting/highlighting of the blank markers, matching Flutter, which also renders the raw text unstyled).
- That passage's 4 `McQuestionCard`s, each labeled `"Chỗ trống ({blankNumber})"` (1-indexed within the passage) instead of Part 5's `"{n}. {sentence}"` — `McQuestionCard` needs no prop or behavior changes; blank type ("select the best sentence" vs. word/phrase) requires no special handling anywhere in the UI, verified against Flutter's actual session screen rendering both identically.

Answers are stored as one flat `(number | null)[]` of length 12, indexed `passageIndex * 4 + questionIndex` — mirroring Flutter's `Part6SessionState.flatIndex(passageIndex, questionIndex)` helper, which this port reproduces as a small local function rather than introducing nested per-passage state. `handleSelectAnswer(passageIndex, questionIndex, optionIndex)` computes the flat index and updates that one slot.

Session phase: "Nộp bài" enabled only once every one of the 12 slots is non-null (`answers.every((a) => a !== null)`), same submit-gating pattern as Part 5.

Result phase: score `X/12` (reusing the `.mc-score` class Part 5 already introduced), then the same passage/blank grouping in `McQuestionCard`'s result mode (`correctIndex`/`explanation` passed, `selected` from the flat answers array at the same flat index) — correct option always highlighted, the user's own wrong pick highlighted, Vietnamese explanation shown beneath each blank. `VocabSuggestionsSection`'s `text` prop is every passage's `passageText` joined with a space (mirrors Flutter's `_passagesText` getter). `"Lưu bài"` (generated sessions only), `"Về trang chính"`, `"Bài khác"` (replays generate or re-fetches a saved exercise depending on `sessionMode`, identical mechanism to Part 5's `handleNewSession` — not a new invention) are all unchanged from Part 5's pattern.

## Error handling

Identical to Part 5, ported without change: missing API key blocks generation with the existing inline Vietnamese message; a malformed/empty AI response (`set.passages.length === 0` after parsing, or every passage dropped by the 4-question filter) throws a Vietnamese error ("AI không trả về bài luyện hợp lệ.") caught into `generateError`, rendered with "Thử lại"/"Về trang chính" on the loading-phase error UI; "Lấy bài có sẵn" finding no match shows the inline notice then falls back to AI generation; a save failure surfaces via `role="alert"` with the save button still available to retry. No redirect-on-missing-params behavior is new here either — a bare `/reading/part6` with no `action` query param redirects to `/reading`, exactly like Part 5.

## Deferred (explicitly out of scope for this spec)

- Part 7 and Nghe — their own future specs, adopting this same hub-integrated pattern from the start.
- Porting Part 6 (or any of this session's already-shipped save/reuse work) to Flutter — Flutter keeps its existing ephemeral Part 6 untouched, per the standing "web trước, Flutter sau" decision.
- Any UI treatment that visually distinguishes "select the best sentence" blanks from word/phrase blanks — Flutter doesn't do this either, and there's no product reason found during brainstorming to diverge from that.
