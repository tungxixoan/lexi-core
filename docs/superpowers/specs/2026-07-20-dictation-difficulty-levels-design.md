# LexiCore — Nghe chép (Dictation) Difficulty Levels Design Spec

**Date:** 2026-07-20
**Status:** Approved
**Covers:** A post-launch enhancement to the already-shipped "Nghe chép" (Dictation) feature (Plan 9, live in production) — adds 3 selectable difficulty levels instead of the single "transcribe the whole sentence" mode.

**Trigger:** User feedback after testing the live feature — full blind transcription was too hard as the only mode.

---

## 1. Goal

Add three difficulty levels to Nghe chép, chosen per session (like the existing Ngôn ngữ/Chủ đề/Cấp độ filters):

- **Dễ** — fill in 2 separate single-word blanks; the rest of the sentence is shown as plain text (cloze-style). The blanked words are not required to be the vocab words used to generate the sentence.
- **Trung bình** — fill in one continuous span covering ~35% of the sentence's words; the rest is shown as plain text.
- **Khó** — unchanged: transcribe the entire sentence from memory, nothing shown. This is exactly what's already live — no behavior change.

Default level = **Khó**, so existing users/sessions see no behavior change unless they explicitly pick a different level.

---

## 2. Non-Goals

- No change to sentence generation (`DictationSource`/`DictationItem`) — the AI prompt and entity are untouched. Difficulty is a purely client-side presentation/grading concern layered on top of the existing generated sentence.
- No change to Khó's existing code path, UI, or scoring — it must remain byte-identical to what's already shipped.
- No change to the audio/replay mechanics (autoplay-never, unlimited replay, −5%/replay penalty) — identical across all three levels.
- No live per-character/per-word feedback while typing, for any level — consistent with Khó's existing "no feedback until submit" rule.

---

## 3. Blank Selection Algorithm

Computed once, client-side, when a session starts — from the existing `DictationItem.target` string, tokenized on whitespace into words (punctuation stays attached to its word, e.g. `"jacket."` is one token — no separate punctuation handling).

- **Dễ:** pick 2 distinct, non-adjacent word indices at random (`|i − j| ≥ 2`) from the range `[1, wordCount − 2]` (excluding index 0 and the last index) whenever `wordCount ≥ 6` (the Dictation prompt already targets 10–18 words, so this is normally satisfied); if `wordCount < 6`, fall back to picking any 2 distinct indices from the full range so the exercise still works on a short sentence. Each is a 1-word blank.
- **Trung bình:** pick one contiguous span of length `clamp(round(wordCount × 0.35), 2, wordCount − 2)`, positioned at a random valid start index so at least 1 word of visible context remains on each side. One multi-word blank.
- **Khó:** no blanks — the entire sentence is one hidden block (current behavior, unchanged).

This runs once per generated sentence (not re-randomized on replay) so the exercise stays stable for the duration of one session.

---

## 4. Data Model

`DictationDifficulty { easy, medium, hard }` — new enum, `dictionary`/`vocabulary`-adjacent entity alongside existing `CEFRLevel`/`AppContext`.

**`DictationSessionState` (presentation-layer, in `dictation_practice_provider.dart`) gains, additively:**

- `difficulty: DictationDifficulty`
- `blanks: List<BlankSpan>` — empty for Khó; for Dễ/Trung bình, each `BlankSpan { startWordIndex, wordCount }` describes one blank's position in the tokenized word list
- `blankAnswers: List<String>` — one entry per blank (length 2 for Dễ, length 1 for Trung bình, unused/empty for Khó)

**Existing fields (`typedText`, `replayCount`, `hasPlayedOnce`, `startedAt`, `isComplete`, `item`) are unchanged in shape and meaning.** Khó continues to use `typedText`/`updateTypedText()` exactly as today. Dễ/Trung bình use a new, parallel `updateBlankAnswer(int blankIndex, String text)` method — `typedText` stays unused for these two levels. This additive split means Khó's state transitions are literally the same code path as what's already shipped; nothing is refactored under it.

**Sentence rendering** (used by both the session screen, editable, and the result screen, read-only) is built once from the word list + `blanks`: a list of alternating `TextSegment(String)` and `BlankSegment(int blankIndex)` values, so one rendering routine serves both screens, parameterized by editable-vs-read-only and by coloring.

---

## 5. Session Screen UI

- **Home screen:** new `FilterTile` "Mức độ" (Dễ / Trung bình / Khó) alongside the existing Ngôn ngữ/Chủ đề/Cấp độ pickers. Default selection = Khó.
- **Khó:** unchanged — Phát/Nghe lại button + one blank `TextField`, nothing of the sentence visible.
- **Dễ/Trung bình:** the segment list renders inline — visible words as plain `Text`, each blank as a small inline text-input widget sized to its span. Dễ shows 2 separate input widgets; Trung bình shows 1 wider one spanning the missing phrase. Play/replay button and the −5%/replay penalty are identical to Khó.
- **Nộp bài enablement:** Khó — same as today (has played once, `typedText` non-empty). Dễ/Trung bình — has played once, **and every blank has non-empty text** (no blank may be left empty).

---

## 6. Grading & SM-2

- **Khó:** unchanged — `charAccuracy` (position-by-position character match) → `finalScore = charAccuracy − 0.05×replayCount` → same SM-2 quality thresholds (≥0.95→5, ≥0.80→4, ≥0.60→3, ≥0.40→2, else→0).
- **Dễ/Trung bình:** each blank is graded as a whole-word exact match, case-insensitive, trimmed (Trung bình's multi-word blank: split the user's phrase on whitespace and compare word-by-word against the target words in that span — every word must match for that blank to count correct). `blockAccuracy = correctBlanks / totalBlanks`. Reuses the **exact same formula and thresholds** as Khó (`finalScore = blockAccuracy − 0.05×replayCount`, same SM-2 mapping) — only the accuracy computation differs, not the downstream scoring pipeline.
  - Known coarseness: Dễ has only 2 blanks, so `blockAccuracy` can only be 0%, 50%, or 100% — a coarser signal than Khó's continuous character-level score, but consistent with the already-accepted "coarse per-sentence SM-2 approximation" philosophy from the original Dictation design.
- SM-2 is still applied to every `VocabRecord` in `item.vocabIds` (the words used to *generate* the sentence) regardless of which words happen to be blanked — unchanged from today. A blank is not required to land on a vocab word (Dễ/Trung bình explicitly allow blanking any word), so this remains a coarse "did practicing this sentence help" signal, not a per-blank-per-vocab-word attribution.

---

## 7. Result Screen

- **Khó:** unchanged — score %, replay count, elapsed time, character-colored diff, full correct sentence, Vietnamese translation.
- **Dễ/Trung bình:** score % (`blockAccuracy`-based), replay count, elapsed time, the same segment-based sentence render used during the session but **read-only and colored** — each blank shows the user's answer in green (correct) or red (incorrect, with the correct word/phrase shown alongside). Full correct sentence and Vietnamese translation still shown underneath, same as Khó.
- Buttons ("Câu khác" / "Về trang chính") unchanged for all levels.

---

## 8. Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Difficulty selection | Per-session `FilterTile`, default Khó | Matches existing Ngôn ngữ/Chủ đề/Cấp độ pattern; default preserves current behavior for existing users |
| Blank source | Client-side, computed from the already-generated sentence | No AI prompt/entity change — keeps generation untouched, minimizes risk |
| Khó code path | Untouched, byte-identical | Already shipped and working; the additive `blanks`/`blankAnswers` fields sit beside it, not through it |
| Blank grading (Dễ/Trung bình) | Whole-word exact match, case-insensitive | Simpler and more intuitive than partial character credit for a "fill in the word" exercise |
| Medium's continuous blank | One text input for the whole phrase | Matches the "nghe rồi chép đoạn đó" feel better than several small boxes in a row |
| Live feedback while typing | None, for any level | Consistent with Khó's existing "no feedback until submit" rule |
| SM-2 formula | Same formula/thresholds for all 3 levels, only accuracy input differs | Reuses already-approved scoring pipeline instead of inventing a second one |

---

## 9. Out of Scope

- Per-word/character partial credit within a Dễ/Trung bình blank (whole-word exact match only)
- Configurable blank count/span size (fixed algorithm in §3, not user-adjustable)
- Difficulty as a persisted global default (Settings-level) — session-only for now
- Any change to how the sentence/vocab words are generated
