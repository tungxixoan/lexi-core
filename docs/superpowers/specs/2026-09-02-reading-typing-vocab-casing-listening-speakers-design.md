# Đọc & gõ advance rule · Vocab headword casing · Listening speaker references — Design

**Date:** 2026-09-02
**Status:** Approved (brainstorming), pending spec review

Three unrelated fixes the user surfaced while testing the React web app, bundled into one spec because they are small and touch overlapping files (the reading passage source, the AI prompts, the vocab save path). Each is independently shippable.

- **A.** Đọc & gõ typing session — stop requiring a 100% exact character match to advance a sentence; normalize "smart" typography in generated passages; prompt the AI to use natural sentence-position capitalization for injected vocab words.
- **B.** Capitalize the first letter of every vocab headword — a one-off Firestore migration for existing records, plus capitalizing on every new-vocab save (web + Flutter).
- **C.** Listening comprehension — keep the structural `speaker: "A" | "B"` label (used to pick TTS voices) but stop the letters "A"/"B" leaking into the spoken dialogue and the questions.

**Both apps are in scope.** The user tests on web; the Flutter app is the only mobile client indefinitely (per `CLAUDE.md`), so prompt/logic changes land on both. TTS/STT/LLM are thin BYOK proxies — every prompt is built client-side, so "fix the prompt" means editing the Dart source and the TypeScript port in lockstep (they already track each other word-for-word, by design).

---

## Part A — Đọc & gõ typing session

### A1. Advance on length, not on an exact match

**Current behavior.** A sentence auto-advances only when the typed text `=== target` exactly (web `bilingual/page.tsx` `handleTypedChange`; Flutter `ReadingPracticeNotifier.updateTypedText`). One wrong character anywhere in the sentence makes an exact match unreachable, so the user is stuck until they find and fix it. There is deliberately no "Next" button (confirmed in the Flutter Bloom spec).

**New behavior.** Advance when `typed.length >= target.length` — i.e. the user has typed to the end of the sentence, regardless of mistakes. Cap the input at `target.length` so it cannot overshoot; with the cap, `>=` is effectively `===` at the moment the last character is typed.

- Per-character accuracy scoring is unchanged. Web `computeSentenceStats(target, value, …)` and Flutter `_advance`'s `for (i < typed.length && i < target.length) if (typed[i] == target[i]) correctChars++` already compare position-by-position and tolerate wrong characters. The result screen's "Độ chính xác" / "Điểm" numbers reflect the mistakes — that is the feedback loop that replaces the hard gate.
- `deletedChars` / `peakMistakes` tracking is unchanged.

**Web changes**
- `apps/web/src/app/(app)/reading/bilingual/page.tsx` — `handleTypedChange`: replace `if (value !== target) return;` with `if (value.length < target.length) return;`. Everything after that line (compute stats, push, advance index or go to result) is unchanged.
- `apps/web/src/components/reading/TypingSentence.tsx` — add `maxLength={currentSentence.target.length}` to the `<input className="reading-type-input">`.

**Flutter changes**
- `lib/features/reading/presentation/providers/reading_practice_provider.dart` — `updateTypedText`: replace `if (text == current.currentSentence.target)` with `if (text.length >= current.currentSentence.target.length)`. `_advance` is unchanged.
- `lib/features/reading/presentation/screens/reading_session_screen.dart` — `_TypingArea`'s `TextField`: add `maxLength: target.length` and `buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null` (the Bloom design has no character counter; the counter widget would otherwise appear under the field).

**Edge cases**
- Paste of a too-long string: prevented by `maxLength` on both platforms.
- The very first sentence with the user having typed nothing: `0 >= N` is false for any real sentence, no premature advance.
- A `target` that is an empty string (malformed AI output): `0 >= 0` is true → it would advance immediately. This already can't happen — an empty `sentences` array throws before the session starts, and a sentence with an empty `target` is a pre-existing latent issue not made worse here. Not addressed.

### A2. Normalize "smart" typography in generated passages

**Problem.** The AI sometimes returns curly quotes / apostrophes (`'` `'` `"` `"`), ellipsis (`…`), en/em dashes (`–` `—`), and non-breaking spaces in the `target` text. The user's keyboard types the ASCII equivalents (`'` `"` `...` `-` `space`), which never match those code points — combined with A1's old exact-match gate this was a hard block, and even with A1 it inflates the mistake count for characters the user typed "correctly".

**Fix.** A pure function `normalizeTypography(s: string): string` applied to every sentence's `target` **and** `vietnamese` immediately after parsing the AI response.

| From | To |
|---|---|
| `‘` `’` `‚` `‛` (curly single quotes / low-9) | `'` |
| `“` `”` `„` `‟` `«` `»` (curly double quotes / guillemets) | `"` |
| `…` (horizontal ellipsis) | `...` |
| `–` `—` `‒` `―` (en/em/figure/horizontal-bar dash) | `-` |
| ` ` ` ` ` ` (nbsp / thin / narrow-nbsp) | ` ` (regular space) |
| `′` `″` (prime / double prime) | `'` `"` |

Applied to `vietnamese` too so the translation line reads consistently, though only `target` is typed.

**Web:** new `apps/web/src/lib/normalizeTypography.ts` (+ test). Call it inside `parseReadingPassage` (`readingPassage.ts`) when building each `BilingualSentence`. Also apply it in the listening and dictation parsers? — **out of scope**; only the reading typing flow requires ASCII-typable text. (Listening/dictation `target` text is spoken and shown, not typed against character-by-character in the same way — dictation uses word-level diff, not exact-char.) Keep the change minimal.

**Flutter:** new helper `lib/core/utils/normalize_typography.dart` (+ test). Call it in `ReadingPassageSource._parse` when constructing each `BilingualSentence` (`target:` and `vietnamese:`).

### A3. Natural sentence-position capitalization for vocab words

**Problem.** The prompt asks the model to list `vocabWords` "exactly as given" and hands it the headword list verbatim. When a stored headword is capitalized (`"Report"`, and after Part B *every* headword is), the model tends to preserve that capitalization mid-sentence — `"He sent the Report yesterday."`.

**Fix — prompt only, both platforms.**
1. Add an instruction: *"Use natural English capitalization based on each word's position in the sentence — lowercase mid-sentence unless the word is a proper noun. Do not copy the capitalization of the vocabulary list."* (swap "English" for the target-language label).
2. Change the `vocabWords` field instruction from `"…exactly as given"` / `"only words from the provided list that appear in this sentence"` to `"…the matching word from the provided list (any capitalization is fine)"`.

**Matching robustness (already mostly fine, one Flutter bug to fix).**
- Web `parseReadingPassage`: `headwordToId` is keyed by `r.headword.toLowerCase()` and looked up with `word.toLowerCase()` — case-insensitive, unaffected.
- Web `highlightVocabWords`: regex has the `i` flag — case-insensitive, unaffected.
- Flutter `ReadingPassageSource._parse`: **`wordMap` is `{for (final w in words) w.headword: w.id}` and looked up with `wordMap[w]` — case-SENSITIVE.** If the AI returns `"report"` but the stored headword is `"Report"`, the vocabId is silently dropped and the word isn't counted/highlighted. **Fix:** build the map lowercased (`{for (final w in words) w.headword.toLowerCase(): w.id}`) and look up with `wordMap[w.toLowerCase()]`. This is a real pre-existing bug that A3 + Part B would otherwise make routine.
- Flutter `_HighlightedText` (session screen): already lowercases both sides (`remaining.toLowerCase().indexOf(word.toLowerCase())`) — unaffected.

---

## Part B — Capitalize vocab headwords

### B0. Shared casing helper

`capitalizeHeadword(s)`: if `s` is non-empty and its first character is a lowercase letter (Unicode-aware — covers accented Latin, not just `a`–`z`), return that character upper-cased + the rest of the string unchanged; otherwise return `s` unchanged.

- `"follow up"` → `"Follow up"`
- `"Follow up"` → `"Follow up"` (idempotent — first char already upper)
- `"TOEIC"` → `"TOEIC"` (already upper)
- `"iPhone"` → `"IPhone"` (accepted edge case — rare in a personal bank; the user fixes it by hand if it ever matters)
- `"3D printing"` → `"3D printing"` (first char not a letter — unchanged)
- `""` → `""`

Implementation: `s.charAt(0).toLowerCase() !== s.charAt(0) && s.charAt(0).toUpperCase() === s.charAt(0)` is the "already upper / not a letter" test — simpler: `const first = s[0]; if (first && first.toLowerCase() === first && first.toUpperCase() !== first) return first.toUpperCase() + s.slice(1); return s;`. Dart: `s[0].toLowerCase() == s[0] && s[0].toUpperCase() != s[0]`.

- **Web:** add to `apps/web/src/lib/vocabDisplay.ts` (existing display-utils module) + test.
- **Flutter:** add `capitalizeHeadword` to `lib/features/vocabulary/domain/entities/vocab_record.dart` as a top-level function or a small `lib/features/vocabulary/domain/headword_casing.dart` + test.

### B1. One-off Firestore migration — `scripts/capitalize-vocab-headwords.js`

Follows the exact pattern of `scripts/migrate-vocab-records-per-language.js` (firebase-admin, `collectionGroup`, dry-run-by-default, `.test.js` against the Firestore emulator).

- **Targets:** for each `lang` in `["vietnamese","english","chinese","korean","japanese"]`, `db.collectionGroup("vocab_records_" + lang)`; plus `db.collectionGroup("vocab_records")` (the deprecated flat backup collection — capitalize it too so a fallback stays consistent).
- **Per document:** compute `next = capitalizeHeadword(data.headword)`. If `next === data.headword` or `headword` is missing/non-string → skip (counted). Else record `{ path, from, to }`.
- **Dry run (default):** print every `{ from → to }` line and the totals (`scanned`, `toChange`, `skipped`), write nothing.
- **`--apply`:** `doc.ref.update({ headword: next, updatedAt: new Date().toISOString() })`, batched (≤ 400 writes/batch, same as the sibling script). Re-print the totals as `changed`.
- **Idempotent:** a second run reports `toChange: 0`.
- **No other field touched.** Saved reading/listening exercises reference `vocabIds` (document ids), not headwords — unaffected. `nextReviewAt` / SM-2 fields untouched.
- **Reversibility:** the change is `lowercase-first-letter → uppercase-first-letter`; the inverse is mechanical if ever needed. `updatedAt` is bumped so a client cache refresh picks it up. No backup collection is made (the transform is trivially inspectable and the dry run is the safety net) — matches how the sibling migration was judged, but call it out in the script header.
- The user runs it manually: `node scripts/capitalize-vocab-headwords.js` (dry run) then `… --apply`, against their own Firebase project credentials, same as the per-language migration.

### B2. Capitalize on new-vocab save

Every path that creates a **new** `VocabRecord` capitalizes the headword. Editing an existing record's other fields does not re-capitalize (leave the user's choice alone).

**Web** — single choke point: `buildVocabRecordDraft` (`apps/web/src/lib/vocabDraft.ts`), used by both Tra từ ("Lưu từ") and the Word Radar / result-screen `VocabSuggestionsSection`. Change `headword: result.headword` → `headword: capitalizeHeadword(result.headword)`. Update `vocabDraft.test.ts`.

**Flutter** — `SaveVocabUseCase.execute` (`lib/features/vocabulary/domain/use_cases/save_vocab_use_case.dart`) is the choke point for saves. At the top of `execute`, replace `record` with `record.copyWith(headword: capitalizeHeadword(record.headword))` and use that for the `existsByHeadword` check, the exception message, and `_repo.save`. **Verify** every new-vocab write routes through this use case (Tra từ save sheet, Word Radar suggestion save); if any path calls `_repo.save` directly, patch it too. Update `save_vocab_use_case_test.dart`.

**Duplicate detection is unaffected:** web `existsByHeadword` queries `where("headword", "==", headword)` — after B1+B2 both sides are consistently capitalized, so an exact-match query still works. If Flutter's `existsByHeadword` is case-sensitive, capitalizing *before* the check (as specified) keeps new saves consistent with the now-capitalized store. "Từ đã học" highlighting in Word Radar already compares `.toLowerCase()` on both sides — unaffected.

---

## Part C — Listening comprehension speaker references (prompt only)

**Unchanged:** the `speaker: "A" | "B" | null` field on each turn, `speakerGenders` derivation, `parseListeningPassage` / `_parse`, the schema, the TTS voice-selection logic. "A"/"B" remain the internal role labels.

**Rewrite** `buildListeningPassagePrompt` (`apps/web/src/lib/listeningPassage.ts`) and `ListeningPassageSource._buildPrompt` (`lib/features/listening/data/sources/listening_passage_source.dart`) — kept word-for-word identical as they are today — to add:

1. **In the dialogue (`turns[].text`):** the two speakers must address each other by natural means only — first names, or pronouns, or nothing. The letters "A" and "B" are internal labels and must never appear as a name or address term in any turn's text.

2. **In the questions (`questions[].question`, written in Vietnamese):** refer to a speaker as follows, and never as "A" or "B":
   - **Conversation, one male + one female speaker** → `"người đàn ông"` / `"người phụ nữ"`.
   - **Conversation, two speakers of the same gender** → by their **role in the situation** when the scenario has clear roles (`"khách hàng"` / `"nhân viên"` / `"quản lý"` / `"lễ tân"` / `"người phỏng vấn"` …), otherwise by the **first name** used in the dialogue.
   - **Talk (single speaker)** → `"người nói"` or `"diễn giả"`.

The model already declares each turn's `gender` and writes its own dialogue, so it has everything it needs to choose the right reference style within one generation — no schema change, no second field.

**Tests:** `listeningPassage.test.ts` and `listening_passage_source_test.dart` currently assert on prompt substrings (e.g. `contains('labeled "A" and "B"')`). Update those assertions to the new wording; add an assertion that the prompt forbids "A"/"B" in the text/questions.

---

## Testing

**Part A**
- `normalizeTypography` unit test: every mapping row above; a string with none of them is returned unchanged; already-ASCII passes through.
- Web `bilingual/page.tsx`: a session test that types a sentence with a deliberate wrong character to full length and asserts it advances to the next sentence (and the recorded accuracy for that sentence is < 100%).
- Web `TypingSentence`: `maxLength` attribute present and equal to `target.length`.
- Flutter `reading_practice_provider_test.dart`: `updateTypedText` with a wrong-character string of full length advances `currentSentenceIndex` and records a `SentenceResult` with `correctChars < totalChars`.
- Flutter `reading_passage_source_test.dart`: the lowercased `wordMap` — an AI response returning a lowercase `vocabWords` entry for a capitalized stored headword still resolves the `vocabId`.
- `parseReadingPassage` / `_parse`: a `target`/`vietnamese` containing curly quotes comes out ASCII.

**Part B**
- `capitalizeHeadword` unit test (both platforms): the table in B0.
- `scripts/capitalize-vocab-headwords.test.js` (emulator): seeds mixed-case headwords across two languages + the flat collection; dry run reports the right `toChange` and writes nothing; `--apply` capitalizes exactly those; a second `--apply` reports `toChange: 0`; a non-string / missing headword is skipped, not thrown.
- Web `vocabDraft.test.ts`: `buildVocabRecordDraft` capitalizes a lowercase `result.headword`.
- Flutter `save_vocab_use_case_test.dart`: `execute` saves the capitalized headword; the `existsByHeadword` check and the "already in your Vocabulary Bank" message use the capitalized form.

**Part C**
- `listeningPassage.test.ts` / `listening_passage_source_test.dart`: prompt no longer contains the old "labeled A and B" phrasing; contains the new dialogue rule and the new question-reference rule; the `{"speaker": "A" or "B" or null, …}` JSON shape line is unchanged.

## Out of scope / not doing

- No character counter UI on the typing field (Bloom design has none).
- No `normalizeTypography` on listening/dictation text (not typed character-exact).
- No schema change for listening (no `name` field per speaker).
- No re-capitalization of headwords when *editing* an existing record's other fields.
- No deletion of the deprecated flat `vocab_records` backup collection (separate cleanup, tracked elsewhere).
- The `context`/register gap in the web reading prompt (no "Ngữ cảnh" setting) stays as-is — a documented pre-existing gap, unrelated.
