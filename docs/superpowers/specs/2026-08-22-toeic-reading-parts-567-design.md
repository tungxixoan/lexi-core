# TOEIC Reading Parts 5/6/7 — Design

## Goal

Bring Flutter's three TOEIC-style reading exercises (Part 5 "Điền câu", Part 6 "Điền đoạn văn", Part 7 "Đọc hiểu") to the React web app, alongside the already-shipped Đọc & gõ — including save/reuse support from day one, since the schema for that was explicitly designed to grow into this. One spec covers the shared architecture for all three; each Part ships as its own implementation plan (Part 5 first, then 6, then 7), matching this repo's established Phase/Part sizing.

## Background

Investigated during brainstorming (2026-08-22): Flutter's `lib/features/reading/{data/sources,domain/entities,presentation}/part{5,6,7}_*` are complete, working, ephemeral (no persistence) implementations. Unlike Đọc & gõ, none of the three use the user's own Vocab Bank — they're calibrated by two independent filters: `AppContext` (register/topic — 8 values, already exists on `VocabRecord.activeContext` but has no settings UI anywhere) and `EconomyVolume` (a TOEIC-specific difficulty tier, `vol2`–`vol5`, unrelated to CEFR). All three share one prompt→parse→session→result shape; they differ only in the AI's JSON schema and how the session/result screens group questions under passages.

Web's Ôn tập currently has flashcards only — no radio-button multiple-choice UI exists anywhere on web yet. This spec introduces the first one.

## Architecture

`apps/web/src/lib/savedReadingExercises.ts`'s `SavedReadingExercise`/`SavedExerciseFilters` become a discriminated union on `type`, so Part 5/6/7 can share the existing `users/{uid}/reading_exercises` collection and its save/random-pick/word-priority-adjacent infrastructure without a schema migration:

```ts
export type ToeicContext = "general" | "business" | "technology" | "travel" | "foodAndDrink" | "health" | "academic" | "socialCasual";
export type EconomyVolume = "vol2" | "vol3" | "vol4" | "vol5";

export interface ToeicFilters {
  appContext: ToeicContext;
  volumes: EconomyVolume[]; // empty = "all volumes", matches Flutter's own "volumes.isEmpty -> use all" rule
}

export interface BilingualFilters { // renamed from today's SavedExerciseFilters, same shape
  topicIds: string[];
  maxCefr: VocabRecord["cefrLevel"] | null;
  wordCount: number | null;
}

export type SavedReadingExercise =
  | { id: string; type: "bilingual"; passage: ReadingPassage; generationFilters: BilingualFilters; targetLanguage: TargetLanguage; createdAt: string }
  | { id: string; type: "part5"; passage: Part5Set; generationFilters: ToeicFilters; targetLanguage: TargetLanguage; createdAt: string }
  | { id: string; type: "part6"; passage: Part6Set; generationFilters: ToeicFilters; targetLanguage: TargetLanguage; createdAt: string }
  | { id: string; type: "part7"; passage: Part7Set; generationFilters: ToeicFilters; targetLanguage: TargetLanguage; createdAt: string };
```

**Migration note**: `SavedExerciseFilters` is the name already shipped and used throughout the live Đọc & gõ code (`page.tsx`, `savedReadingExercises.ts`, and both files' tests). Renaming it to `BilingualFilters` is a real rename of already-shipped, tested code, not a green-field addition — the first task of the Part 5 implementation plan must do this rename (and update every call site/test) as its own explicit step, verified by the full existing Đọc & gõ test suite still passing unchanged afterward, before any Part-5-specific code is added.

`getRandomSavedExercise`'s matching logic gains a same-`type` requirement as its first check (already anticipated, per the just-completed final review's Finding 4 — this spec is the first real consumer of that guard). Topic/level/word-count matching only applies to `"bilingual"`; Part 5/6/7 match on `appContext` (exact) and `volumes` (overlap, or either side empty = matches anything — mirrors Flutter's own "empty selection = all volumes" default). `getAllUsedVocabIds` is `"bilingual"`-only by nature (Part 5/6/7 have no `vocabIds` field) and already skips non-`"bilingual"` documents per the same Finding 4 fix.

Each Part gets its own small domain-logic file mirroring `readingPassage.ts`'s existing shape:
- `apps/web/src/lib/part5.ts` — `Part5Question`, `Part5Set`, `buildPart5Prompt(context, targetLanguage, volumes)`, `parsePart5Set(json)`.
- `apps/web/src/lib/part6.ts` — `Part6Question`, `Part6Passage`, `Part6Set`, `buildPart6Prompt(...)`, `parsePart6Set(json)`.
- `apps/web/src/lib/part7.ts` — `Part7Question`, `Part7PassageGroup`, `Part7Set`, `buildPart7Prompt(...)`, `parsePart7Set(json)` (includes the shape-validation Flutter calls `_hasValidShape`).

A new shared UI component, `apps/web/src/components/shared/ContextDropdown.tsx`, wraps `SimpleDropdown` for the 8-value `ToeicContext` picker — reused identically by Parts 5, 6, and 7 (and available for Nghe later). A new shared component, `apps/web/src/components/reading/McQuestionCard.tsx`, renders one question's prompt text + radio options + (in result mode) correct/wrong coloring and explanation — parameterized enough that Part 5 (flat list), Part 6 (grouped under a passage), and Part 7 (grouped under 1-2 documents) all wrap it rather than each hand-rolling radio UI.

## UI flow (identical shape for all three Parts; only content grouping differs)

**Hub (`/reading`)**: three new cards alongside the existing "✍️ Đọc & gõ" — "📝 Part 5 — Điền câu", "📄 Part 6 — Điền đoạn văn", "📖 Part 7 — Đọc hiểu". Flat, same hub, no nested sub-hub.

**Setup (`/reading/part5`, `/part6`, `/part7`)**: two filters — "Chủ đề" (`ContextDropdown`, single-select, defaults to `"general"`; no persistence, no Cài đặt field, matches the Vietnamese-script-and-defaults pattern already established for Đọc & gõ's own documented gaps) and "Độ khó" (multi-select `EconomyVolume`, empty = "Tất cả"). Two buttons: "Tạo bài luyện" (AI-generate) and "🔀 Lấy bài có sẵn" (random pick) — **neither is gated by a minimum-word rule**, since none of these three Parts touch the Vocab Bank at all; the only real precondition is having an API key configured, checked the same way Đọc & gõ already does.

**Session**: every question rendered up front on one scrollable page via `McQuestionCard`, "Nộp bài" (submit) enabled only once every question has a selected answer. Part 5 renders a flat list of `McQuestionCard`s. Part 6 renders one card per passage (full `passageText`, then its 4 `McQuestionCard`s as "Chỗ trống (1)"–"(4)"). Part 7 renders one card per passage group (1 or 2 documents shown in full, then its `McQuestionCard`s numbered per question) — the double-document group's card visually marks itself as such ("Đoạn N (2 văn bản liên quan)"), matching Flutter.

**Result**: score `X/N`, per-question breakdown reusing `McQuestionCard` in its result mode (green check/red X, correct option highlighted green, the user's wrong pick highlighted red, Vietnamese explanation shown beneath), `VocabSuggestionsSection` reused unchanged (`text` = every question's prompt text and passage/document text joined, `existingRecords`/`topics` fetched the same way Đọc & gõ's result screen already does), "Lưu bài" (visible only for `sessionMode === "generated"`, same pattern as Đọc & gõ), "Bài khác" (replays whichever mode the session started in — AI-generate again, or another random pick excluding the just-saved id — identical mechanism to Đọc & gõ's "Sinh bài mới", not a new invention), "Về trang chính".

## Prompts

Ported verbatim from Flutter's `part{5,6,7}_source.dart` (already read and quoted in full during brainstorming), with the one addition already standard across this web app: "Every 'explanation' field must use only Vietnamese script — never Chinese, Japanese, or other non-Vietnamese characters."

- **Part 5**: exactly 15 independent sentences, each with one `"___"` blank testing grammar or vocabulary-in-context, 4 options, `correctIndex`, Vietnamese explanation. JSON: `{"questions":[{"sentenceWithBlank","options","correctIndex","explanation"}]}`.
- **Part 6**: exactly 3 short business documents (email/memo/notice/ad/article), each with exactly 4 numbered inline blanks `(1)___`–`(4)___`; at least one blank per passage must be a "select the best sentence" item (options are full sentences, not words). JSON: `{"passages":[{"passageText","questions":[{"options","correctIndex","explanation"}]}]}`.
- **Part 7**: exactly 3 passage groups in order — 2 single-document groups (3-4 questions each, different document types from each other) then 1 double-document group (exactly 5 questions, at least one requiring both documents, the two documents genuinely related). JSON: `{"passageGroups":[{"documents":["..."],"questions":[{"question","options","correctIndex","explanation"}]}]}`. Parsing validates the shape (3 groups; first two single-document with 3-4 questions; third exactly 2 documents and exactly 5 questions) and throws a Vietnamese error if the AI's response doesn't match, exactly mirroring Flutter's `_hasValidShape`.

## Error handling

- No API key configured: disable both buttons, same inline message pattern as Đọc & gõ.
- Malformed AI response (wrong question/passage/group count, wrong shape): a clear Vietnamese error ("AI không trả về bài hợp lệ."), retry available — Part 7's shape check is the strictest and most important to get right given its 3-group/double-document structure.
- "Lấy bài có sẵn" finds no match: same inline-notice-then-AI-fallback as Đọc & gõ.
- Save failure: `role="alert"`, button stays available to retry.

## Deferred (explicitly out of scope for this spec)

- Nghe (Nghe chép / Nghe hiểu) — its own future spec.
- Porting any of this (Đọc & gõ's save/reuse, or Part 5/6/7 themselves) to Flutter — per the earlier "Web trước, Flutter sau" decision; Flutter keeps its existing ephemeral Part 5/6/7 untouched for now.
- Adding a real "Chủ đề"/context field to Cài đặt — Part 5/6/7 manage this filter as page-local state only, defaulting to `"general"`.
- Any generic multiple-choice exercise type for Ôn tập/Practice — `McQuestionCard` is built for this spec's three Parts; extending it elsewhere is a future decision, not implied by building it here.
