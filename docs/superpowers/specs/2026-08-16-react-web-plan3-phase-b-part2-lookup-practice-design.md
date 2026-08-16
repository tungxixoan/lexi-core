# LexiCore — Tra từ (Lookup) + Ôn tập (Practice): React Web Plan 3 Phase B, Part 2

**Date:** 2026-08-16
**Status:** Approved
**Covers:** The `/lookup` and `/practice` screens for the Next.js web app — the second and final sub-spec of React Web Plan 3 Phase B. `/practice` is relabeled "Ôn tập" in the sidebar (the route itself is unchanged).
**Depends on:** React Web Plan 3 Phase B Part 1 (Cài đặt) — `users/{uid}/settings/config` holds the active provider/model/API-key-ciphertext and `targetLanguage` this sub-spec's AI calls need; React Web Plan 3 Phase A + its Polish addendum — reuses `getVocabRecords`, `TopicFilterPopover`, `EditVocabModal`'s field pattern, and the app shell/sidebar.
**Followed by:** Nothing currently planned — this closes out React Web Plan 3 Phase B. Dashboard/streak, Đọc/Nghe hubs, and Flutter-side sync are all separate later phases (see Deferred section).

---

## 1. Goal

Give the web app two more real screens: **Tra từ** (AI-backed dictionary lookup, with save-to-Vocab-Bank) and **Ôn tập** (SM-2 spaced-repetition flashcard review of already-saved words) — the two remaining pieces of the original 12-screen Bloom inventory that depend on a working BYOK key (now live via Cài đặt).

## 2. Scope & Non-Goals

**In scope:** `/lookup` (word/phrase/sentence dictionary lookup, save-to-Vocab-Bank flow) and `/practice` (relabeled "Ôn tập" — session setup filters, flashcard review loop, session result screen, batch SM-2 update).

**Non-goals:**
- **No AI in Ôn tập.** Unlike Flutter's practice session (which calls an AI to generate multiple-choice/fill-in-blank/translation exercises for ~70% of reviews of already-seen words), web's Ôn tập is Flashcard-only — front/back card using data already in Firestore (headword, IPA, meaning, first example), no `generateContent` call anywhere in this flow. A deliberate simplification decided during this brainstorm, not an oversight.
- **Dashboard/streak** — still deferred to its own later phase (per the Cài đặt sub-spec's Deferred section). This sub-spec prepares for it (see §3.2.4) but does not build it.
- **Đọc/Nghe hubs** — separate later phase, per the umbrella spec's phase ordering. Not touched here.
- **Flutter-side changes** — none. Web reads/writes the same `vocab_records`/`topics` collections Flutter already uses; no schema change that would break Flutter's reads.
- **"Gợi ý từ mới" (new-word suggestion grid)** below the Vocab Bank list, and any suggestion-grid-after-practice-session feature — explicitly deferred in the Phase A plan already (needs an upstream suggestion source that doesn't exist yet); still not built here.
- **Multiple-choice/fill-in-blank/translation exercise types** — dropped per the AI-free decision above. If AI-backed exercises are wanted later, that's new scope for a future spec, not a gap in this one.

---

## 3. Design

### 3.1 Tra từ (Lookup)

**Flow**, mirroring Flutter's `lookup_provider.dart`:
1. User types a query into a search box. Client-side input-type detection (word / phrase / sentence) — port Flutter's exact `InputDetector` rule (`lib/core/utils/input_detector.dart`, verified): trimmed input ending in `.`/`?`/`!` → sentence; otherwise more than 4 space-separated words → sentence; 2–4 words → phrase; 0–1 words → word.
2. **Word/phrase**: check the user's saved Vocab Bank first via a new, targeted Firestore query — `getVocabRecordByHeadword(uid, headword, targetLanguage)` (a `where("headword", "==", ...)` query scoped to the user's `vocab_records` subcollection, NOT a full-bank fetch like Vocab Bank's own `getVocabRecords` — 290+ docs is too expensive to reload just to check one headword). If found, display instantly, no AI call, and hide the "Lưu" flow entirely (already saved, offer a "Xem trong Ngân hàng từ vựng" link to the existing record instead — this is new UI, no Flutter precedent needed since Flutter's own cache-hit path returns a lighter/different result shape).
3. If not found, call `generateContent` with the currently-active provider/model/key from `users/{uid}/settings/config` (read via `useSettingsContext()`, same pattern as Cài đặt) and the user's `targetLanguage`. Prompt asks for JSON matching `WordPhraseResult`'s fields (headword, ipa, meaning, examples, definition, synonyms, suggestedTopics, cefrLevel) — port Flutter's `gemini_dictionary_source.dart` prompt structure, parsed the same defensive way `generateContent`'s existing provider modules already parse AI JSON.
4. **Sentence** queries: call the AI for a translation only (`original`/`translation` shape, matching `SentenceResult`). No save flow — sentences are never saved to Vocab Bank, matching Flutter exactly (confirmed, not to be changed).
5. Word/phrase results show a **"Lưu vào Ngân hàng từ vựng"** button that opens the *same* `EditVocabModal` component Vocab Bank already uses for editing (`apps/web/src/components/vocab-bank/EditVocabModal.tsx`) — its field set (Nghĩa, Ví dụ add/remove, Chủ đề max 2, Ghi chú) is already an exact match for what Flutter's `SaveVocabSheet` exposes. Reused in "create" mode: same UI, but `onSave` calls a new `saveVocabRecord(uid, record)` (generates a new doc ID via Firestore's `doc(collection(...))` auto-ID, matching the existing `vocab_records` document shape exactly — `cefrLevel` defaults to the AI's suggested level or `"b1"` if absent, `targetLanguage`/`activeContext` come from the user's current settings, `sm2*` fields default to their zero/fresh-word values, `createdAt`/`updatedAt` set to now) instead of `updateVocabRecord`.
6. Topic pre-selection: same as Flutter — match the AI's `suggestedTopics` (plain strings) against the user's existing `topics` by name, pre-check up to 2 matches in the modal before the user even opens it.

### 3.2 Ôn tập (Practice/Review)

**3.2.1 Sidebar rename.** `apps/web/src/components/shell/Sidebar.tsx`'s `/practice` nav item label changes from "🎯 Luyện tập" to "🎯 Ôn tập". Route path (`/practice`) and file locations are unchanged — this is a display-label-only change.

**3.2.2 Session setup screen.** Filter row reusing the established popover pattern (`TopicFilterPopover`, already built for Vocab Bank): Chủ đề (multi-select popover, same component), Trình độ (CEFR max level, single-select), Số từ/phiên (5/10/20/Tất cả, matching Flutter's options). Word pool logic: **due-today words** (`nextReviewAt` null or ≤ now) matching the active filters; if that set is empty, automatically widen to **any word** matching the filters (no due-date constraint) rather than showing an empty state. Shuffle the resulting list client-side, truncate to the selected count, and start the session — no Firestore write happens at this point (matches Flutter: filtering/shuffling is a pure client-side operation over the already-loaded word list).

**3.2.3 Flashcard review loop.** One card on screen at a time, built from the confirmed visual-companion mockup:
- **Flip mechanics**: `rotate3d(1, 1, 0, Ndeg)` — a diagonal hinge (not a straight horizontal or vertical axis) — where N is a monotonically-increasing counter incremented by 180 on every flip (front→back, back→front, or grade-and-advance), never decremented. This means the card always spins in the same rotational direction; two consecutive flips complete a full visual 360°. `backface-visibility: hidden` on both faces, `transform-style: preserve-3d` on the flipping element, `perspective` on its wrapper — same technique as the mockup, ported to a real component (`FlashcardCard.tsx` or similar) with actual `VocabRecord` data instead of the mockup's hardcoded 3-word array.
- **Front face**: headword (large), IPA (small, italic, muted), a hint row ("Chạm vào thẻ để xem đáp án"). Tapping anywhere on the front flips to the back.
- **Back face**: meaning, first example sentence (italic, muted) — **not** all examples, matching Flutter's `record.examples.first` — a "chạm để lật lại" hint, then two buttons: **"Chưa hiểu"** (outlined/danger-toned) and **"Đã hiểu"** (filled/accent). Tapping the meaning/example area (not the buttons) flips back to the front *without* recording anything, letting the user re-study before grading — same word stays in place. Tapping either button records an in-memory `ExerciseResult` (`quality: 1` for "Chưa hiểu", `quality: 5` for "Đã hiểu") for the current word, flips back to front, and advances to the next word's front face (or, if this was the last word, transitions to the result screen).
- Progress indicator above the card: "Từ N / M" plus a thin fill bar.

**3.2.4 Session result screen.** Shown once every word in the session has been graded. Percentage circle/number (green if ≥70%, red/danger otherwise, matching Flutter's threshold), "N / M từ đúng", a scrollable list of every word in the session with a correct/incorrect icon + headword + meaning, and a "Ôn tập lại" button that returns to the session setup screen. **On mount, this screen performs the batch SM-2 update**: for every graded word, run the standard SM-2 formula (ported 1:1 from `compute_sm2_use_case.dart` — quality < 3 resets repetitions/interval and schedules tomorrow; quality ≥ 3 advances repetitions, computes the new interval (1st rep → 1 day, 2nd → 6 days, further reps → `interval × easeFactor`), and adjusts `easeFactor` by `+0.1 - (5-quality)×0.08`, clamped to `[1.3, 2.5]`) and write the updated `sm2Repetitions`/`sm2EaseFactor`/`sm2Interval`/`nextReviewAt`/`updatedAt` fields back to that word's `vocab_records` doc — a new `updateVocabRecordSm2(uid, id, sm2Fields)` function, since the existing `updateVocabRecord`/`VocabRecordUpdate` type only covers `meaning`/`examples`/`topicIds`/`personalNotes` and deliberately excludes SM-2 fields (Vocab Bank's edit modal was never meant to touch them). This is a genuine Firestore write per word (matches Flutter's own per-word loop in `session_result_screen.dart`, not a single batched write — Firestore batched writes are a possible follow-up optimization, not required now).
- **Streak/stats readiness, not implementation**: the point where this batch SM-2 update completes (all words written, session genuinely over) is the single, well-defined "session completed" event the future streak feature will hook into. This sub-spec does not write to a `streak` collection or call any stats service — it only ensures that event is a single clear function call site (not scattered across the flashcard loop), so adding `await writeStreakEntry(uid, today)` there later is a one-line addition, not a refactor.

### 3.3 Data layer additions

New functions needed in `apps/web/src/lib/vocabRecords.ts` (or a sibling file, per implementation-plan judgment):
- `getVocabRecordByHeadword(uid, headword, targetLanguage): Promise<VocabRecord | null>` — targeted query, not a full-bank fetch.
- `saveVocabRecord(uid, record): Promise<string>` — creates a new doc, returns its id. Used only by Lookup's save flow.
- `updateVocabRecordSm2(uid, id, sm2Fields): Promise<void>` — narrow update covering only `sm2Repetitions`/`sm2EaseFactor`/`sm2Interval`/`nextReviewAt`/`updatedAt`. Used only by the session result screen's batch update.

New pure function: `computeSm2(record, quality): Sm2Fields` — port of `compute_sm2_use_case.dart`, colocated with the practice-session code (not a Firestore-touching function itself, easy to unit test in isolation with fixed `Date.now()`).

No new Firestore collections. No changes to `VocabRecord`'s shape (already has every SM-2 field this needs, from React Web Plan 3 Phase A).

---

## 4. Key Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Ôn tập exercise types | Flashcard only, no AI | User explicitly removed AI from this flow mid-brainstorm — simpler, faster, no BYOK spend for reviewing already-known words |
| Flip animation | Diagonal hinge (`rotate3d(1,1,0,...)`), monotonically increasing rotation (never reverses direction) | Chosen after live visual-companion comparison against a straight top-bottom hinge; user preferred the diagonal, and wanted the second flip to continue spinning rather than un-rotate |
| Due-word pool fallback | Empty due-set → widen to any word matching filters | Never show a dead-end empty session |
| SM-2 write timing | Batch, all at once on the result screen | Matches Flutter exactly; also naturally creates the single "session complete" event streak/stats will need later |
| Lookup save UI | Reuse `EditVocabModal` in create mode | Its field set (meaning/examples/topics-max-2/notes) already exactly matches Flutter's `SaveVocabSheet` — no new component needed |
| Sentence lookups | Translation only, never saveable | Matches Flutter exactly; Vocab Bank only ever holds words/phrases |
| Vocab-Bank-first check | Targeted `where("headword", ...)` query, not a full-bank fetch | Avoids re-downloading 290+ docs on every Lookup page visit just to check one word |

---

## 5. Deferred / Open Follow-ups

- **Streak/stats collection** — not built here; this sub-spec only guarantees a single clean hook point for it (§3.2.4).
- **Firestore batched writes** for the result screen's per-word SM-2 update (currently N sequential writes, matching Flutter's own loop) — a possible later optimization, not required now.
- **AI-backed exercise types** (multiple-choice/fill-in-blank/translation) — deliberately dropped from Ôn tập's scope. Revisit only if explicitly requested later; not a gap to silently fill in.
- **Flutter-side changes** — none anticipated; this sub-spec only reads/writes fields Flutter already produces and understands.
