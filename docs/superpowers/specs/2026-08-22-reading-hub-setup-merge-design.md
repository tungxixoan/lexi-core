# Reading Hub / Setup Merge — Design

## Goal

Collapse the `/reading` hub and each mode's separate setup screen into one screen: pick a shared "Chủ đề" (topic) filter once, pick which mode to practice, adjust that mode's own secondary filter, then generate or reuse — all without a page navigation until the actual session starts. Currently: hub → click a card → separate `/reading/bilingual` or `/reading/part5` setup screen → session. After this: hub does everything setup used to do; the destination pages start directly in session/result.

## Background

Đọc & gõ's "Chủ đề" filter (`TopicFilterPopover`, multi-select over the user's own Vocab Bank `Topic` documents) and Part 5's "Chủ đề" filter (a fixed 8-value `ToeicContext` enum, single-select, unrelated to the Vocab Bank) look alike but are structurally different. Confirmed during brainstorming (2026-08-22): making "Chủ đề" genuinely shared across modes means Part 5 must switch from the fixed enum to real Vocab Bank topics — this spec includes that data-model change, not just a UI relocation. "Trình độ"/"Độ khó" (CEFR vs. TOEIC EconomyVolume) measure different things and stay mode-specific; only their reveal moves onto the hub.

## Architecture

**Hub (`/reading`) becomes the single setup surface:**
1. `TopicFilterPopover` (reused unchanged) — one topic selection, shared by every mode.
2. A mode picker: toggle-style buttons (not `<Link>`s) for "✍️ Đọc & gõ" / "📝 Part 5 — Điền câu", each keeping its existing description text. Selecting one is local state, not navigation. No mode is selected by default on page load.
3. Once a mode is selected, that mode's own secondary filter appears below: "Trình độ tối đa"/"Số từ" dropdowns for Đọc & gõ, or the Độ khó volume chips for Part 5. Before any mode is picked, this area and the action buttons are hidden entirely.
4. Two action buttons, "Tạo bài luyện" / "🔀 Lấy bài có sẵn" — same gating as today: for Đọc & gõ, "Tạo bài luyện" is replaced by the existing "chưa đủ từ" hint below 5 matching words (computed via `selectSessionWords(records, {...filters, count: null}).length`, exactly as today); "Lấy bài có sẵn" is never gated by word count, for either mode. Clicking either navigates to `/reading/bilingual` or `/reading/part5` with the chosen filters and action encoded as query params.

**Part 5's data model changes** (`apps/web/src/lib/savedReadingExercises.ts`, `apps/web/src/lib/part5.ts`, `apps/web/src/lib/toeicFilters.ts`):
- `ToeicFilters` changes from `{ appContext: string; volumes: string[] }` to `{ topicIds: string[]; volumes: string[] }` — now the same shape family as `BilingualFilters`.
- `matchesToeic` changes from exact-`appContext`-equality to topic-overlap (mirroring `matchesBilingual`'s topic logic exactly: empty selection matches anything, otherwise at least one shared id).
- `buildPart5Prompt(topicNames: string[], targetLanguage, volumes)` — takes resolved topic **names** (strings, e.g. `"Business"`, `"Travel"` — resolved from the selected `Topic` documents by the caller) instead of a `ToeicContext` enum value, since the AI prompt needs a human-readable label, not an id. Empty topic list → the prompt drops the "in a ... register/setting" clause entirely rather than defaulting to a fake "general" register.
- `toeicFilters.ts`'s `ToeicContext`/`TOEIC_CONTEXTS`/`CONTEXT_LABELS` are deleted (dead code once nothing reads them — verified no other consumer before removing). `EconomyVolume`/`ECONOMY_VOLUMES`/`VOLUME_LABELS`/`VOLUME_PROMPT_HINTS` are unchanged.

**Migration note**: `buildPart5Prompt`'s signature, `ToeicFilters`'s shape, and `matchesToeic`'s logic are all already-shipped, already-reviewed code from the Part 5 plan (not green-field) — this is a real breaking-signature refactor, same category as the `SavedExerciseFilters`→`BilingualFilters` migration the Part 5 plan itself did to Đọc & gõ. The implementation plan's first task must: update `buildPart5Prompt`'s signature and its existing tests in `part5.test.ts`, update `matchesToeic` and its existing tests in `savedReadingExercises.test.ts`, and update `part5/page.tsx`'s `currentFilters()`/`handleSaveExercise`/`fetchSavedExercise` call sites — verified by that task's own full test suite passing before any hub-page work begins, mirroring how the Part 5 plan's own Task 1 was sequenced.

**Destination pages (`/reading/bilingual`, `/reading/part5`) lose their setup phase:**
- No more filter dropdowns, no more "Tạo bài luyện"/"Lấy bài có sẵn" buttons on these pages — `phase` starts effectively at "loading", reading `topicIds`/`maxCefr`/`wordCount`/`action` (bilingual) or `topicIds`/`volumes`/`action` (Part 5) from `useSearchParams()` on mount, then immediately calling `handleGenerate()` or `fetchSavedExercise()` (both already exist, unchanged internally) based on `action`.
- Missing or malformed query params (direct URL entry, stale bookmark, browser back button landing here with no state) → redirect to `/reading` immediately via `router.replace("/reading")`, mirroring the existing "session is null → back to hub" pattern already used elsewhere in this codebase.
- Anywhere the old `resetToSetup()` used to flip `phase` back to `"setup"` (the "not enough words to even attempt AI" fallback, and any other reset-to-setup path) now calls `router.push("/reading")` instead — there is no more local setup state to fall back to.
- Each page keeps its own `getVocabRecords`/`getTopics` fetch on mount (needed for `VocabSuggestionsSection` on the result screen) — this duplicates the hub's own fetch of the same data, which is an accepted, unavoidable cost of separate page loads in this multi-page architecture, not a regression to fix here.

## Query param encoding

- `/reading/bilingual?topicIds=id1,id2&maxCefr=b1&wordCount=10&action=generate` — `topicIds` comma-separated (omitted/empty = no topic filter), `maxCefr` omitted for null, `wordCount` a number or `all` for null, `action` is `generate` or `existing`.
- `/reading/part5?topicIds=id1,id2&volumes=vol2,vol3&action=existing` — `topicIds` same encoding, `volumes` comma-separated (omitted/empty = all volumes), `action` same two values.

## Error handling

- No/invalid query params on direct load → redirect to `/reading`, no dead-end screen.
- Everything else (API key missing, malformed AI response, no saved match + fallback, save failure) is unchanged from what's already shipped on both pages — only the entry point into `handleGenerate()`/`fetchSavedExercise()` changes (from a button click to a mount-time effect reading query params), not their internal behavior.

## Deferred (explicitly out of scope for this spec)

- Part 6/7/Nghe — when built, their own plans adopt this same hub pattern (shared topic filter, mode-specific secondary filter) from the start; nothing here needs revisiting for them.
- Persisting the hub's filter selections across visits — each visit to `/reading` starts from a fresh default state, matching the rest of this app's existing pages.
- Any change to `selectSessionWords`, `getAllUsedVocabIds`, `prioritizeUnusedWords`, or `matchesBilingual` — all unchanged.
