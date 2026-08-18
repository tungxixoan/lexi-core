# LexiCore — Đọc & gõ (Reading & Typing): React Web Plan 3 Phase C, Part 1

**Covers:** Porting Flutter's "Đọc & gõ" (bilingual reading + sentence-by-sentence typing practice) to the Next.js web app (`apps/web/`). First sub-spec of React Web Plan 3 Phase C ("Đọc/Nghe hubs and their session/result screens" per the master spec §10) — Part 5/6/7 TOEIC reading and the Nghe (Listening) hub are separate, later sub-specs, matching how Flutter itself built this feature set across 3 separate plans.

## 1. Goal

Give the web app a `/reading` hub (currently a placeholder sidebar link with no route) and its first real mode: `/reading/bilingual` — an AI-generated bilingual passage the user types out sentence-by-sentence, sourced from their own Vocab Bank words, with live color-coded typing feedback and a result screen matching Flutter's scoring/suggestions behavior.

## 2. Scope & Non-Goals

**In scope:**
- Reading hub screen with one real card (Đọc & gõ); Part 5/6/7 cards deferred to their own later sub-specs.
- Full setup → session → result flow for Đọc & gõ, at parity with Flutter's feature set (see §3).
- A new shared `VocabSuggestionsSection` component (result-screen "gợi ý từ mới") — reusable by future result screens (Part 5/6/7, Nghe hiểu) the same way Flutter's `ResultSuggestionsSection` is shared.

**Non-goals (explicitly deferred, not forgotten):**
- Part 5, Part 6, Part 7 (TOEIC reading) — separate sub-specs, later.
- Nghe (Listening) hub — separate sub-spec, later, needs React Web Plan 2's live TTS/STT (already built, not yet wired into any web screen).
- **Streak recording.** Flutter's result screen calls `recordPracticeSession(...)` into local SharedPreferences stats. The web app has no streak infrastructure yet (Dashboard + streak collection is its own deferred phase — see project memory `web_app_no_local_storage.md`, re-confirmed still deferred as of 2026-08-18). This spec does **not** write to any streak collection. But per the same precedent set by Ôn tập's `SessionGradeResult`, the reading-session result data captured here (accuracy, word count, completion) must be shaped so a future streak feature can read it without refactoring this code — see §3.3.
- **SM-2 / spaced-repetition impact.** Matches Flutter exactly: Đọc & gõ never reads or writes any `vocab_records` SM-2 field. It only *reads* headword/meaning/examples to build the AI prompt.
- Flutter-side changes or cross-app sync of anything — web-only, same pattern as every prior React Web Plan 3 sub-spec.

## 3. Design

### 3.1 Screen flow

```
/reading                    — hub (1 card: Đọc & gõ; Part 5/6/7 cards added in later sub-specs)
/reading/bilingual           — setup: filters + word-count + Tạo bài luyện
/reading/bilingual/session   — the passage + typing practice
/reading/bilingual/result    — stats + vocab-suggestions
```

State machine shape matches `/practice/page.tsx`'s established `Phase = "setup" | "session" | "result"` pattern — one page component per mode, not one component per phase.

**Setup screen:** reuses `TopicFilterPopover` and `SimpleDropdown` (target language, max CEFR, word count — same components already built for Ôn tập/Cài đặt, same Bloom chip+panel look). A live preview shows how many Vocab Bank words currently match the filters. If that count is **< 5** (Flutter's `_minVocabWords` threshold, ported as-is), the "Tạo bài luyện" button is replaced by a message: *"Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có N từ."* — no AI call is possible below this threshold, matching Flutter exactly.

Word selection for the prompt: same due-word-preferred selection Ôn tập already uses (`selectSessionWords`'s due-then-fallback-to-all logic) — words with `nextReviewAt` null or in the past are prioritized, filled out to the requested count. This reuses, not reimplements, that logic (see §3.3).

**Session screen — the passage + typing area:**

Three elements, confirmed via live visual-companion iteration with the user (2 rounds — an initial 3-row version with a separate feedback line was simplified down to 2 rows once the user pointed out the passage display itself already shows the current sentence and can carry the color feedback directly, removing the redundant third row):

1. **Passage display** — every sentence so far, with the *current* sentence rendered specially: as the user types into the input below, each typed character is compared against the target sentence and colored inline, character-by-character (green = correct, red-on-red-background = wrong), directly inside the passage's current-sentence span. Untyped remainder stays in the normal (unstyled) passage color. Past sentences and the passage as a whole fade per Flutter's existing opacity treatment (already-typed 0.3, current 1.0, upcoming dimmer).
2. **Vietnamese translation row** — the *current* sentence's Vietnamese translation only, in a small highlighted container below the passage. (The first visual draft omitted this row entirely; the user caught the omission and it's back in for the final design — this is a hard requirement, not optional polish.)
3. **A single plain `<input>`** below the translation row for typing. This is the deliberate divergence from Flutter's implementation: Flutter overlays a color-coded `RichText` behind a transparent `TextField` sharing exact font metrics — its own code comments flag this as fragile, and the web visual-companion session reproduced a real bug from the equivalent single-element `contentEditable` alternative (cursor/space-character glitches from re-rendering `innerHTML` on every keystroke and re-placing the caret). The chosen design avoids both fragile patterns: the `<input>` is never re-styled or overlaid — the browser manages its cursor natively — and the color feedback renders in a *separate* element (the passage's current-sentence span), which has no cursor to preserve and can be freely re-rendered on every keystroke.

Progress indicator: "Câu N / M" + a fill bar (matching Ôn tập's `.practice-progress-row`/`.practice-progress-track` pattern, reused directly).

Advancing: when the typed value exactly equals the target sentence, the app records that sentence's stats (see §3.2), clears the input, and moves to the next sentence. On the last sentence, transitions to the result phase.

### 3.2 Scoring

Ported exactly from `reading_practice_provider.dart`, per-sentence and aggregated across the whole passage:

- **Deletion tracking:** every `onChange` where the new input value is *shorter* than the previous one increments that sentence's `deletedChars` by the character-count difference (a plain "did the input shrink" check — this also naturally covers select-all-and-retype, not just single backspaces).
- **Per-sentence stats:** `correctChars` (index-wise match count against the target at completion time), `totalChars` (target length), `deletedChars`, `durationMs`.
- **Aggregate result:**
  - `overallAccuracy = sum(correctChars) / sum(totalChars)`
  - `deletionRatio = sum(deletedChars) / sum(totalChars)`
  - `finalScore = clamp(overallAccuracy - 0.5 × deletionRatio, 0, 1)`
  - `wpm = (sum(typedChars) / 5) / (totalDurationMs / 60000)` (standard "5 chars = 1 word" WPM convention, matching Flutter)

### 3.3 Result screen

Four stat cards: Độ chính xác (`overallAccuracy × 100`%), Tốc độ (WPM), Thời gian (formatted duration), Điểm (`finalScore × 100`%) — same 4-card row as Flutter.

Below that: the list of Vocab Bank words actually used in the generated passage (headword + meaning), then the new shared `VocabSuggestionsSection` (§3.4).

Buttons: "Sinh bài mới" (discards the current passage, returns to setup with the same filters still selected — mirroring the "Ôn tập lại ngay" pattern from Ôn tập's result screen, which reuses `handleStart()` directly against already-selected filter state) / "Về trang chính" (back to the reading hub).

**Streak-hook shape (not wired to anything yet, per §2):** the result computation should produce one clean object — `{ vocabIds: string[], accuracy: number, completedAt: string }` — as the single place a future streak feature would read from, the same way Ôn tập's `SessionGradeResult` was shaped as that hook. No Firestore write happens here in this spec.

### 3.4 `VocabSuggestionsSection` (new shared component)

Ports `result_suggestions_section.dart` + `vocab_suggestions_section.dart`, merged into one component (the split between "loading wrapper" and "presentation" doesn't carry its own value in a function-component world the way it does in Flutter's `ConsumerStatefulWidget` model).

**Critical design point, corrected mid-brainstorm by the user:** the AI call that generates suggestions must return **full dictionary info per suggested word** (headword, IPA, meaning, definition, examples, synonyms, suggestedTopics, cefrLevel — the same shape as `WordPhraseResult`) in a *single* call, not a bare list of words that would need a second lookup call per word before they could be saved. This mirrors the "Khám phá từ mới" fix already applied to Tra từ (merged 2 AI calls into 1) — the same principle applies here from the start rather than needing a follow-up fix.

**Corrected during self-review against the actual Flutter source** (`word_radar_source.dart`, `find_known_headwords_use_case.dart`): this is not "invent N new words" — it's "scan the passage text itself for up to 10 words/phrases already in it that are worth learning," excluding ones the user already knows. "Already knows" is determined *before* the AI call, client-side, with no extra Firestore round-trip: a case-insensitive substring scan of the passage text against the `records` already loaded for the setup screen's filters (`text.toLowerCase().includes(record.headword.toLowerCase())`), collecting the matching headwords into a `knownHeadwords` list passed into the prompt as words to exclude. Prompt: given the passage text, target language, target CEFR level, and `knownHeadwords`, ask for up to 10 words/phrases *from the text* worth learning (excluding `knownHeadwords`), each with the full `WordPhraseResult` JSON shape — empty `suggestions` array is a valid response if nothing in the passage is worth surfacing.

Behavior:
- Each suggestion renders as a card (headword, IPA, meaning, CEFR pill).
- Tapping a card opens `EditVocabModal` in `mode="create"`, pre-filled from that suggestion's already-fetched data — no further AI call, reusing the exact component and save flow already built for Tra từ.
- **"Lưu tất cả"** button (confirmed in scope) bulk-saves every not-yet-saved, not-dismissed suggestion using the same default-field construction `EditVocabModal`'s create mode would use (no per-item editing UI for the bulk path) — skipping any that fail (e.g. a duplicate headword) rather than aborting the whole batch, matching Flutter's `_saveAll`.
- Each card also gets a dismiss (✕) button to hide it without saving.
- A saved card shows a checkmark instead of the tap-to-open affordance.
- Load failure shows an inline error + "Thử lại" retry button, scoped to just this section (doesn't block the rest of the already-rendered result screen).
- If AI is unavailable (no API key configured for the active provider), the whole section doesn't render — matches how the setup screen's generate button is hidden below the Cài đặt.

### 3.5 Data layer additions

- `apps/web/src/lib/readingPassage.ts` — `buildReadingPassagePrompt(headwords, targetLanguage, cefrLevel)`, `parseReadingPassage(json): ReadingPassage`. Pure functions, ported from `reading_passage_source.dart`'s prompt/parse logic (same "~0.75 sentences per headword, clamped 6–12" sizing rule).
  - `interface BilingualSentence { target: string; vietnamese: string; vocabWords: string[] }`
  - `interface ReadingPassage { sentences: BilingualSentence[]; vocabIds: string[] }` — `vocabIds` resolved from `vocabWords` via a headword→id map built from the words that were fed into the prompt, same as Flutter.
- `apps/web/src/lib/vocabSuggestions.ts` — `buildVocabSuggestionsPrompt(text, targetLanguage, cefrLevel, existingHeadwords)`, `parseVocabSuggestions(json): WordPhraseResult[]`. Reuses `WordPhraseResult` from `@/lib/lookup` (Tra từ's existing type) rather than declaring a parallel type.
- `apps/web/src/lib/readingScoring.ts` — pure `computeSentenceStats`/`computeFinalScore` functions per §3.2, unit-testable in isolation from any React state.
- Nothing new is written to Firestore by this spec — `ReadingPassage`/session state lives only in the page's React state for the duration of the session, same as Ôn tập's `sessionWords`/`sessionResults` before its batch SM-2 write (except here, nothing gets written back at all).

## 4. Key Decisions

| Decision | Choice | Why |
|---|---|---|
| Typing feedback UI | Single plain `<input>`, color feedback rendered in the passage's current-sentence span (not overlaid, not `contentEditable`) | Avoids Flutter's known font-alignment fragility *and* a reproduced `contentEditable` caret bug found live during design; browser manages cursor natively |
| Vietnamese translation row | Kept, current-sentence-only | User explicitly caught its omission in an early simplified mockup — non-negotiable, not polish |
| Vocab suggestions data shape | Full `WordPhraseResult` per suggestion in one AI call | User explicitly required this — matches the already-established "Khám phá từ mới" one-call pattern, and matches what Flutter already does (`WordRadarAiResult.suggestions: List<WordPhraseResult>`) |
| Bulk save | "Lưu tất cả" button included | Confirmed in scope, matches Flutter's `_saveAll` |
| Streak | Not wired to any collection | Dashboard + streak is a separately deferred phase (3rd time re-confirmed deferred, 2026-08-18); this spec only shapes the result data for a future hook |
| SM-2 | Untouched | Matches Flutter exactly — reading/typing practice has no spaced-repetition side effects |
| Word selection | Reuses due-then-fallback logic already built for Ôn tập | DRY — same selection semantics, no reason to diverge |
| Scoring formula | Ported exactly (`finalScore = accuracy − 0.5 × deletionRatio`) | Shared conceptual behavior with Flutter even though this data isn't cross-app synced — no reason to invent a different formula |

## 5. Deferred / Open Follow-ups

- Part 5, Part 6, Part 7 (TOEIC reading) — own sub-specs, later, per the master spec's Phase C decomposition.
- Nghe (Listening) hub — own sub-spec, later.
- Streak collection + Dashboard — deferred phase, re-confirmed 2026-08-18 (third time). Do not lose the `{ vocabIds, accuracy, completedAt }` result shape decided in §3.3 when that phase starts.
- `VocabSuggestionsSection` is built shared/reusable from day one specifically so Part 5/6/7 and Nghe hiểu's result screens (later sub-specs) can consume it without rework, mirroring Flutter's own `ResultSuggestionsSection` sharing across 4 screens.
